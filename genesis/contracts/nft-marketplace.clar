;; NFT Marketplace Contract for Evolutionary Creatures
;; Enables listing, buying, and trading of evolutionary creatures with advanced features

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u200))
(define-constant ERR-NOT-FOUND (err u201))
(define-constant ERR-LISTING-EXPIRED (err u202))
(define-constant ERR-PRICE-MISMATCH (err u203))
(define-constant ERR-ALREADY-LISTED (err u204))
(define-constant ERR-NOT-LISTED (err u205))
(define-constant ERR-INSUFFICIENT-BALANCE (err u206))
(define-constant ERR-INVALID-PARAMS (err u207))
(define-constant LISTING-DURATION u1440) ;; ~10 days in blocks
;; Data Variables
(define-data-var marketplace-fee uint u25) ;; 2.5% fee in basis points
(define-constant MINIMUM-PRICE u1000000) ;; 1 STX minimum listing price

;; Data Variables
(define-data-var total-listings uint u0)
(define-data-var total-volume uint u0)

;; Define data maps
(define-map listings
    {id: uint}
    {
        seller: principal,
        price: uint,
        expiry: uint,
        creature-id: uint,
        status: (string-ascii 10)
    }
)

(define-map sale-history
    {creature-id: uint}
    {
        last-price: uint,
        total-sales: uint,
        highest-price: uint
    }
)

;; Private Functions
(define-private (calculate-fee (price uint))
    (/ (* price (var-get marketplace-fee)) u1000)
)

(define-private (transfer-nft (creature-id uint) (from principal) (to principal))
    (contract-call? .nfta transfer creature-id from to)
)

(define-private (is-listing-valid (listing-id uint))
    (match (map-get? listings {id: listing-id})
        listing (and
            (is-eq (get status listing) "active")
            (< block-height (get expiry listing))
        )
        false
    )
)

;; Read-only Functions
(define-read-only (get-listing (listing-id uint))
    (ok (map-get? listings {id: listing-id}))
)

(define-read-only (get-listing-price (listing-id uint))
    (match (map-get? listings {id: listing-id})
        listing (ok (get price listing))
        (err ERR-NOT-FOUND)
    )
)

(define-read-only (get-sale-history (creature-id uint))
    (ok (map-get? sale-history {creature-id: creature-id}))
)

;; Public Functions
(define-public (list-creature (creature-id uint) (price uint))
    (let
        ((seller tx-sender)
         (new-listing-id (+ (var-get total-listings) u1))
         (current-owner (unwrap! (contract-call? .nfta get-owner creature-id) ERR-NOT-FOUND)))
        
        ;; Validation checks
        (asserts! (is-eq (unwrap! current-owner ERR-NOT-FOUND) tx-sender) ERR-NOT-AUTHORIZED)
        (asserts! (>= price MINIMUM-PRICE) ERR-INVALID-PARAMS)
        
        ;; Create listing
        (map-set listings
            {id: new-listing-id}
            {
                seller: seller,
                price: price,
                expiry: (+ block-height LISTING-DURATION),
                creature-id: creature-id,
                status: "active"
            }
        )
        
        ;; Update total listings
        (var-set total-listings new-listing-id)
        (ok new-listing-id)
    )
)

(define-public (cancel-listing (listing-id uint))
    (let
        ((listing (unwrap! (map-get? listings {id: listing-id}) ERR-NOT-FOUND)))
        
        ;; Validation
        (asserts! (is-eq (get seller listing) tx-sender) ERR-NOT-AUTHORIZED)
        (asserts! (is-eq (get status listing) "active") ERR-NOT-LISTED)
        
        ;; Update listing status
        (map-set listings
            {id: listing-id}
            (merge listing {status: "cancelled"})
        )
        (ok true)
    )
)

(define-public (buy-creature (listing-id uint))
    (let
        ((listing (unwrap! (map-get? listings {id: listing-id}) ERR-NOT-FOUND))
         (price (get price listing))
         (seller (get seller listing))
         (creature-id (get creature-id listing))
         (fee (calculate-fee price))
         (seller-amount (- price fee)))
        
        ;; Validation checks
        (asserts! (is-listing-valid listing-id) ERR-LISTING-EXPIRED)
        (asserts! (not (is-eq tx-sender seller)) ERR-INVALID-PARAMS)
        
        ;; Process payment
        (try! (stx-transfer? price tx-sender seller))
        (try! (stx-transfer? fee tx-sender CONTRACT-OWNER))
        
        ;; Transfer NFT
        (try! (transfer-nft creature-id seller tx-sender))
        
        ;; Update sale history
        (match (map-get? sale-history {creature-id: creature-id})
            prev-history (map-set sale-history
                {creature-id: creature-id}
                {
                    last-price: price,
                    total-sales: (+ (get total-sales prev-history) u1),
                    highest-price: (if (> price (get highest-price prev-history))
                        price
                        (get highest-price prev-history))
                })
            ;; If no previous history exists
            (map-set sale-history
                {creature-id: creature-id}
                {
                    last-price: price,
                    total-sales: u1,
                    highest-price: price
                })
        )
        
        ;; Update listing status and volume
        (map-set listings
            {id: listing-id}
            (merge listing {status: "sold"})
        )
        (var-set total-volume (+ (var-get total-volume) price))
        
        (ok true)
    )
)

(define-public (update-listing-price (listing-id uint) (new-price uint))
    (let
        ((listing (unwrap! (map-get? listings {id: listing-id}) ERR-NOT-FOUND)))
        
        ;; Validation
        (asserts! (is-eq (get seller listing) tx-sender) ERR-NOT-AUTHORIZED)
        (asserts! (is-eq (get status listing) "active") ERR-NOT-LISTED)
        (asserts! (>= new-price MINIMUM-PRICE) ERR-INVALID-PARAMS)
        
        ;; Update listing price
        (map-set listings
            {id: listing-id}
            (merge listing {price: new-price})
        )
        (ok true)
    )
)

;; Admin Functions
(define-public (update-marketplace-fee (new-fee uint))
    (begin
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
        (asserts! (<= new-fee u100) ERR-INVALID-PARAMS)
        (ok (var-set marketplace-fee new-fee))
    )
)

;; Initialize contract
(begin
    (print "NFT Marketplace initialized")
)