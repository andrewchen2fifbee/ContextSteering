# ContextSteering
ContextSteering is a Roblox library that helps your NPCs make situationally aware movement decisions.

ContextSteering provides you control over what behaviors run, when they run, and what context they consider. You can extend ContextSteering with your own custom behaviors.

ContextSteering is NOT a replacement for PathfindingService. Steering behaviors, improved or not, can't help your NPCs solve mazes. If you need both NPC pathfinding and "smart" local movement behaviors, combine ContextSteering with PathfindingService (ex. try to context steer towards the next pathfinding node, but prioritize avoiding attacks over reaching the destination).

## What is context steering?
Short version:
- Context steering is an improvement on normal steering behaviors. F1 2010's developers created context steering to simplify and improve the game's racing AI.
- Steering behaviors allow NPCs to make local movement decisions.
- Unfortunately, steering behaviors have two major problems.
    - Steering behaviors are greedy. Maybe there's a better choice, but it's not obvious to a machine.
    - Separate movement decisions from different behaviors are added together. Behaviors can cancel each other out, causing individual NPCs to act strangely.
- Context steering fixes one problem: It gives NPCs the situational awareness to make a single decision where behaviors don't fight each other.
    - Context steering uses context maps. These are arrays describing how interesting or dangerous each direction around an NPC is.
        - Directions close to an interesting (or dangerous) direction are less interesting, but not uninteresting. This will be important later.
    - Different behaviors return separate information about an NPC's surroundings.
        - Behaviors return information instead of decisions. Only one decision is made at the end.
        - This stops behaviors from canceling each other out. 
    - Context maps are combined in a non-additive manner: Only the strongest (most important) interest and danger information in each direction is kept.
        - You could use a different combining function to get different behavior.
    - The combined context map is used to make a movement decision.
    - NPCs hate danger. An NPC won't move in a direction if it's more dangerous than another direction.
        - Because nearby directions also become interesting or dangerous, this causes NPCs to move around the danger, taking a safer (better) path that eventually leads to the target.
- Context steering is still flawed. NPCs will make better decisions, but those decisions can still be bad decisions.
    - Context steering is still greedy. It doesn't make the best choice. It makes a "looks good to me" choice.
    - NPCs will still get stuck in dead ends with context steering. Context steering is not a replacement for a pathfinding system. If your world has complex geometry, use a pathfinding system. You can always combine context steering with pathfinding.

Long version:
- Steering behaviors: https://gamedevelopment.tutsplus.com/series/understanding-steering-behaviors--gamedev-12732
- Context steering: https://www.gameaipro.com/GameAIPro2/GameAIPro2_Chapter18_Context_Steering_Behavior-Driven_Steering_at_the_Macro_Scale.pdf

## Example usage flow:
- Describe the individual behaviors your NPC should have. Different behaviors generally need different information about interesting things near your NPC.
    - For example: The archer wants to... (in order of importance)
        - Stay away from enemies with swords, because swordfighting with a bow is a very bad (dangerous) idea.
        - Dodge enemy arrows. They hurt, duh.
        - Get in position to attack nearby enemies, so the archer can help its team win.
        - Stay near teammates, because they can help the archer if an enemy attacks.
- Call matching behavior functions, providing information and behavior parameters that represent your intent.
    - Behaviors return context maps. Context maps describe what the area near your NPC is like, based on the information given to the behavior.
    - Returned context maps do not differentiate between things being interesting or dangerous. It's your job to know if something is interesting or dangerous to your NPC, and use the returned context map appropriately.
    - IMPORTANT: Using behaviors to get danger information is counterintuitive. If something is dangerous, you should actually have your NPC call behaviors to approach the danger, but then treat the returned context map as a danger map instead of an interest map.
    - For example: The archer wants to...
        - Stay away from enemies with swords -> should Pursue enemies with low RangeMax (everything is good as long as they're far away) and very high InterestMax (not dying is very important). Treat the returned context map as a danger map!
        - Dodge enemy arrows -> should Pursue enemy arrows with medium-high RangeMax (arrows are fast) and high InterestMax (important, but less important than avoiding sword enemies). Treat the returned context map as a danger map!
        - Get in position to attack enemies -> should Seek enemies with medium InterestMax, but only when the archer can't see an enemy. There are better ways to get in position, but this is a good starting point. You are responsible for tracking whether the archer can see an enemy, and for choosing to call or not call the behavior.
        - Stay near teammates -> should Seek teammates with medium RangeMax (if they're too far away, it's not worth it) and low InterestMax (we care, but not that much - waiting is boring to see!).
- Process the returned interest and danger maps, then use the final best direction and interest level to make a movement decision.

[//]: # (TODO: Installation instructions)

[//]: # (TODO: Proofread)

[//]: # (TODO: Create usage example/demo place)

[//]: # (TODO: Consider Moonwave + workflow actions for generating + publishing autodoc)