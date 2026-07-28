Status: pending

# 02: Coin Pickup Sound

## What to build
Add Sound component to Coin entity with a pickup sound. When player collects coin, play the sound before entity is destroyed.

## Files to create/modify
- src/entities/coin.lua — add Sound component, define pickup sound
- res/sfx/coin_pickup.wav (add placeholder or real file)

## Test approach
Integration test: load coin fixture map, simulate player collision, verify `sound:play('pickup')` called. Mock audio source capture.

## Acceptance criteria
- [ ] Coin entity has Sound component with pickup sound
- [ ] Pickup triggers `entity.sound:play('pickup')` in Pickup component or Coin
- [ ] Sound plays when coin collected in integration test
- [ ] Integration test passes

## Blocked by
01 — Sound component must exist