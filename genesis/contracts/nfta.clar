;; Constants for configuration
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-NOT-FOUND (err u101))
(define-constant ERR-CANNOT-BREED (err u102))
(define-constant ERR-INVALID-PARAMS (err u103))
(define-constant ERR-COOLDOWN-ACTIVE (err u104))
(define-constant BREEDING-COOLDOWN u144) ;; ~24 hours in blocks
(define-constant EVOLUTION-THRESHOLD u100) ;; interaction points needed to evolve

;; Define the NFT token
(define-non-fungible-token evolutionary-creature uint)

;; Data variables
(define-data-var last-token-id uint u0)
(define-data-var mint-price uint u100000000) ;; 100 STX

;; Principal data maps
(define-map creature-traits 
    {id: uint} 
    {
        dna: (buff 32),
        generation: uint,
        birth-block: uint,
        parent1-id: (optional uint),
        parent2-id: (optional uint),
        evolution-stage: uint,
        interaction-points: uint,
        last-breed-block: uint
    }
)

(define-map approved-operators 
    {owner: principal, operator: principal} 
    bool
)

;; Read-only functions
(define-read-only (get-owner (id uint))
    (ok (nft-get-owner? evolutionary-creature id))
)

(define-read-only (get-creature-traits (id uint))
    (map-get? creature-traits {id: id})
)

(define-read-only (can-breed (id1 uint) (id2 uint))
    (let
        ((creature1 (unwrap! (map-get? creature-traits {id: id1}) false))
         (creature2 (unwrap! (map-get? creature-traits {id: id2}) false))
         (current-block block-height))
        (and
            (>= (- current-block (get last-breed-block creature1)) BREEDING-COOLDOWN)
            (>= (- current-block (get last-breed-block creature2)) BREEDING-COOLDOWN)
            (not (is-eq id1 id2))
        )
    )
)

;; Generate pseudo-random DNA using block information
(define-private (generate-random-dna)
    (let
        ((entropy (unwrap-panic (get-block-info? burnchain-header-hash (- block-height u1)))))
        (sha256 entropy)
    )
)

;; Combine parent DNA for breeding
(define-private (combine-parent-dna (dna1 (buff 32)) (dna2 (buff 32)))
    (let
        ((slice1 (unwrap-panic (slice? dna1 u0 u16)))
         (slice2 (unwrap-panic (slice? dna2 u16 u32)))
         (combined (concat slice1 slice2)))
        (sha256 combined)
    )
)

;; Validation functions
(define-private (is-valid-id (id uint))
    (and 
        (>= id u1)
        (<= id (var-get last-token-id))
    )
)

(define-private (is-valid-operator (operator principal))
    (and 
        (not (is-eq operator CONTRACT-OWNER))
        (not (is-eq operator tx-sender))
    )
)

;; Public functions
(define-public (mint)
    (let
        ((new-id (+ (var-get last-token-id) u1)))
        (try! (stx-transfer? (var-get mint-price) tx-sender CONTRACT-OWNER))
        (try! (nft-mint? evolutionary-creature new-id tx-sender))
        (map-set creature-traits
            {id: new-id}
            {
                dna: (generate-random-dna),
                generation: u1,
                birth-block: block-height,
                parent1-id: none,
                parent2-id: none,
                evolution-stage: u1,
                interaction-points: u0,
                last-breed-block: u0
            }
        )
        (var-set last-token-id new-id)
        (ok new-id)
    )
)

(define-public (breed (id1 uint) (id2 uint))
    (let
        ((owner1 (unwrap! (nft-get-owner? evolutionary-creature id1) ERR-NOT-FOUND))
         (owner2 (unwrap! (nft-get-owner? evolutionary-creature id2) ERR-NOT-FOUND))
         (creature1 (unwrap! (map-get? creature-traits {id: id1}) ERR-NOT-FOUND))
         (creature2 (unwrap! (map-get? creature-traits {id: id2}) ERR-NOT-FOUND))
         (new-id (+ (var-get last-token-id) u1)))
        
        ;; Check ownership and breeding conditions
        (asserts! (is-eq tx-sender owner1) ERR-NOT-AUTHORIZED)
        (asserts! (can-breed id1 id2) ERR-CANNOT-BREED)
        
        ;; Create new creature
        (try! (nft-mint? evolutionary-creature new-id tx-sender))
        (map-set creature-traits
            {id: new-id}
            {
                dna: (combine-parent-dna (get dna creature1) (get dna creature2)),
                generation: (+ (get generation creature1) u1),
                birth-block: block-height,
                parent1-id: (some id1),
                parent2-id: (some id2),
                evolution-stage: u1,
                interaction-points: u0,
                last-breed-block: block-height
            }
        )
        
        ;; Update parent breeding cooldowns
        (map-set creature-traits
            {id: id1}
            (merge creature1 {last-breed-block: block-height})
        )
        (map-set creature-traits
            {id: id2}
            (merge creature2 {last-breed-block: block-height})
        )
        
        (var-set last-token-id new-id)
        (ok new-id)
    )
)

(define-public (interact (id uint))
    (begin
        ;; Validate ID
        (asserts! (is-valid-id id) ERR-INVALID-PARAMS)
        (let
            ((creature (unwrap! (map-get? creature-traits {id: id}) ERR-NOT-FOUND))
             (current-points (get interaction-points creature))
             (new-points (+ current-points u1)))
            
            ;; Add interaction point
            (map-set creature-traits
                {id: id}
                (merge creature {interaction-points: new-points})
            )
            
            ;; Check if evolution is possible
            (if (and 
                    (>= new-points EVOLUTION-THRESHOLD)
                    (< (get evolution-stage creature) u4))
                (begin
                    (map-set creature-traits
                        {id: id}
                        (merge creature {
                            interaction-points: u0,
                            evolution-stage: (+ (get evolution-stage creature) u1)
                        })
                    )
                    (ok true)
                )
                (ok false)
            )
        )
    )
)

;; SIP-009 NFT Interface Implementation
(define-public (transfer (id uint) (sender principal) (recipient principal))
    (begin
        ;; Validate inputs
        (asserts! (is-valid-id id) ERR-INVALID-PARAMS)
        (asserts! (not (is-eq recipient sender)) ERR-INVALID-PARAMS)
        (asserts! (is-eq tx-sender sender) ERR-NOT-AUTHORIZED)
        (nft-transfer? evolutionary-creature id sender recipient)
    )
)

(define-public (set-approved (operator principal) (approved bool))
    (begin
        (asserts! (is-valid-operator operator) ERR-INVALID-PARAMS)
        (ok (map-set approved-operators {owner: tx-sender, operator: operator} approved))
    )
)

(define-read-only (get-approved (id uint))
    (ok none)
)

;; Contract initialization
(begin
    (map-set approved-operators {owner: tx-sender, operator: CONTRACT-OWNER} true)
    (print "Evolutionary NFT contract initialized")
)