Status: pending

# 10: Enemy Sounds (Spider/Robot)

## What to build
Add Sound component to Spider and Robot entities with:
- Spider: web shoot, web hit (wrap), idle skitter
- Robot: motor hum (looped while chasing), stomp stun sound
Trigger from enemy state machines/behaviors.

## Files to create/modify
- src/entities/spider.lua (or wherever spider is defined — check entities/)
- src/entities/robot.lua (or wherever robot is defined)
- res/sfx/spider_web.wav, res/sfx/spider_wrap.wav, res/sfx/spider_skitter.wav
- res/sfx/robot_motor.wav, res/sfx/robot_stomp.wav

## Test approach
Integration test: spawn spider, simulate player in range, verify web sound; simulate wrap, verify wrap sound. Robot: spawn, chase player, verify motor sound loops; stomp, verify stun sound.

## Acceptance criteria
- [ ] Spider has Sound component with web/wrap/skitter sounds
- [ ] Robot has Sound component with motor/stomp sounds
- [ ] Sounds trigger correctly from enemy behaviors
- [ ] Integration tests pass

## Blocked by
01 — Sound component must exist