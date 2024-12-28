# Evolutionary NFT Smart Contract

A Clarity smart contract for creating, breeding, and evolving NFT creatures on the Stacks blockchain. This contract implements an interactive NFT system where creatures can breed, evolve, and gain interaction points over time.

## Features

### Core Functionality
- Mint new creatures
- Breed existing creatures to create offspring
- Interactive evolution system
- Cooldown periods for breeding
- DNA inheritance system
- Generation tracking
- SIP-009 NFT standard compliance

### Technical Specifications
- Minting price: 100 STX
- Breeding cooldown: 144 blocks (~24 hours)
- Evolution threshold: 100 interaction points
- Maximum evolution stage: 4
- DNA size: 32 bytes

## Contract Functions

### Public Functions

#### `mint()`
Mints a new creature NFT.
- Requires payment of 100 STX
- Returns: ID of the newly minted creature
- Error cases: Insufficient funds, mint failure

#### `breed(id1: uint, id2: uint)`
Breeds two creatures to create a new one.
- Parameters:
  - `id1`: ID of the first parent
  - `id2`: ID of the second parent
- Requirements:
  - Caller must own at least one parent
  - Parents must be different creatures
  - Parents must be off cooldown
- Returns: ID of the newly bred creature
- Error cases: Not authorized, breeding cooldown active, invalid IDs

#### `interact(id: uint)`
Adds an interaction point to a creature and checks for evolution.
- Parameters:
  - `id`: ID of the creature to interact with
- Returns: 
  - `true` if evolution occurred
  - `false` if no evolution
- Error cases: Invalid ID, creature not found

#### `transfer(id: uint, sender: principal, recipient: principal)`
Transfers ownership of a creature.
- Implements SIP-009 transfer standard
- Error cases: Not authorized, invalid parameters

#### `set-approved(operator: principal, approved: bool)`
Sets approval for an operator to manage creatures.
- Error cases: Invalid operator, not authorized

### Read-Only Functions

#### `get-owner(id: uint)`
Returns the owner of a creature.

#### `get-creature-traits(id: uint)`
Returns all traits of a specific creature.

#### `can-breed(id1: uint, id2: uint)`
Checks if two creatures can breed.

#### `get-approved(id: uint)`
Returns approved operators for a creature (SIP-009 compliance).

## Data Structures

### Creature Traits
```clarity
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
```

## Security Features

- Input validation for all public functions
- Cooldown enforcement for breeding
- Owner-only transfer restrictions
- Principal validation for operators
- Error handling for all operations

## Error Codes

- `ERR-NOT-AUTHORIZED (u100)`: Unauthorized operation
- `ERR-NOT-FOUND (u101)`: Creature not found
- `ERR-CANNOT-BREED (u102)`: Breeding conditions not met
- `ERR-INVALID-PARAMS (u103)`: Invalid parameters
- `ERR-COOLDOWN-ACTIVE (u104)`: Breeding cooldown still active

## Installation and Deployment

1. Clone the repository
2. Deploy using Clarinet or your preferred Stacks deployment tool
3. Initialize contract with required parameters

## Testing

Recommended test scenarios:
1. Minting new creatures
2. Breeding mechanics
3. Evolution system
4. Transfer functionality
5. Approval system
6. Error handling

## Best Practices

1. Always check creature ownership before operations
2. Handle all errors appropriately
3. Verify breeding cooldowns
4. Validate all input parameters