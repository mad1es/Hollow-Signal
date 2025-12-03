# Hollow Signal
## Complete Game Concept for Midterm Assignment

---

## 1. Game Title and General Information

### Game Name
**Hollow Signal**

### Genre
**Psychological Horror / Interactive Experience / AR Horror**

### Platform
**iOS** (requires iOS 17.0+)

### Brief Description
Hollow Signal is an innovative horror experience for iOS that creates a sense of something watching the player through their phone's sensors. The game uses real data from gyroscope, microphone, proximity sensor, and camera to create an atmosphere of paranormal observation, where the boundary between reality and perception blurs.

---

## 2. Storyline and Narrative Structure

### Main Conflict
In 2019, a group of neuroscientists from the University of Toronto began researching a rare condition they called **"sensory desynchronization"** (Sensory Desync). In 0.03% of the population, there is a microscopic delay between what the senses register, what the brain processes, and what the person becomes aware of. When this delay exceeds 200 milliseconds, the brain begins to "fill in the gaps" with its own interpretations—this is called **"phantom interpolation"**.

The player launches an application that supposedly documents these anomalies in real time. But the longer they use the app, the more anomalies it detects. The app begins to react to the player's movements, analyze their breathing, comment on their state. Gradually, a sense arises that something is watching the player—not through the screen, but through the player themselves.

### Game World
The action takes place in the player's real world—in their room, in their home. The app uses real phone sensors to create a sense of presence. The game world is the player's world, but distorted through the prism of sensory desynchronization.

### Key Events
1. **App Launch** (0:00-0:05) — black screen, text "wait..."
2. **First Interaction** (0:05-0:30) — "Are you there?" — the game begins to establish contact
3. **Establishing Contact** (0:30-1:30) — "I'm trying to understand" — the game analyzes the player's voice
4. **Observations** (1:30-3:00) — the game comments on the player's state: "You're tired", "You're tense", "Heart faster"
5. **First Task** (3:00-5:00) — "Tell me what you see around you" — the game tests perception of reality
6. **Deepening Contact** (5:00-7:00) — "Come closer" — the game uses the proximity sensor
7. **Anomalies** (7:00-10:00) — voice echo effects, movement predictions, breathing synchronization
8. **Conclusion** (10:00+) — "I'm not in the phone. I'm in you. And you know it."

### Emotional Journey
The player begins with curiosity or skepticism, then transitions to mild discomfort, then to tension, and finally to fear. The game uses psychological techniques to build tension: it doesn't show monsters, doesn't use loud sounds—it creates a sense of presence through subtle hints and observations.

### Narrative Tone
Dark, mysterious, minimalistic. The game speaks in short phrases, uses metaphors and hints. It never directly mentions sensors or technical details—instead, it speaks of "feelings" and "observations". The tone is serious but not pompous—it creates a sense of reality of what's happening.

---

## 3. Gameplay Process

### How the Player Starts
1. Player launches the app on iPhone
2. App requests permissions for microphone, camera, and speech recognition
3. Screen turns black, text "wait..." appears (typed letter by letter)
4. App begins recording audio and analyzing phone movements in the background

### Core Gameplay Loop
1. **App displays text** — short phrases that appear with typing effect
2. **Player reacts** — says something, moves the phone, touches the screen, or stays silent
3. **App analyzes** — uses sensors to analyze player actions
4. **App reacts** — generates response through LLM or shows pre-recorded reaction
5. **Loop repeats** — game gradually transitions to the next phase

### Progression System
The game progresses through 8 phases, each lasting a specific time:
- **Phase 1: Loading** (0:00-0:05) — establishing atmosphere
- **Phase 2: Initial Contact** (0:05-0:30) — establishing connection
- **Phase 3: Establishing Contact** (0:30-1:30) — voice analysis
- **Phase 4: Observations** (1:30-3:00) — commenting on state
- **Phase 5: First Task** (3:00-5:00) — testing perception
- **Phase 6: Deepening Contact** (5:00-7:00) — using proximity sensor
- **Phase 7: Anomalies** (7:00-10:00) — echo effects, predictions
- **Phase 8: Conclusion** (10:00+) — final phrases

### Evolution of Difficulty and Tension
- **0:00-1:30**: Low tension — game only establishes contact
- **1:30-5:00**: Medium tension — game begins commenting on player state
- **5:00-7:00**: High tension — game requires physical proximity
- **7:00-10:00**: Maximum tension — anomalies appear (echo, predictions)
- **10:00+**: Climax — final phrases about "it" being not in the phone, but in the player

### Gameplay Process Diagram

```
[App Launch]
        ↓
[Loading: "wait..."]
        ↓
[Phase 1: Initial Contact]
    ├─ Player speaks → "I hear you"
    ├─ Player silent → "Silence is also an answer"
    └─ Player moves → "Something changed"
        ↓
[Phase 2: Establishing Contact]
    ├─ Voice analysis
    └─ Reactions to intonation
        ↓
[Phase 3: Observations]
    ├─ "You're tired"
    ├─ "You're tense"
    └─ "Heart faster"
        ↓
[Phase 4: First Task]
    ├─ "Tell me what you see"
    └─ Reactions to answers
        ↓
[Phase 5: Deepening Contact]
    ├─ "Come closer"
    └─ Using proximity sensor
        ↓
[Phase 6: Anomalies]
    ├─ Voice echo
    ├─ Movement predictions
    └─ Breathing synchronization
        ↓
[Phase 7: Conclusion]
    └─ "I'm in you. And you know it."
```

### Player-System Interaction Diagram

```
┌─────────────────────────────────────────────────────────┐
│                    PLAYER                               │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐            │
│  │  Voice   │  │ Movement │  │  Touch   │            │
│  └────┬─────┘  └────┬─────┘  └────┬─────┘            │
│       │            │            │                      │
└───────┼────────────┼────────────┼──────────────────────┘
        │            │            │
        ▼            ▼            ▼
┌─────────────────────────────────────────────────────────┐
│              PHONE SENSORS                               │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐            │
│  │Microphone│  │Gyroscope │  │Proximity │            │
│  └────┬─────┘  └────┬─────┘  └────┬─────┘            │
│       │            │            │                      │
└───────┼────────────┼────────────┼──────────────────────┘
        │            │            │
        ▼            ▼            ▼
┌─────────────────────────────────────────────────────────┐
│              ANALYSIS SYSTEM                             │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐            │
│  │Speech    │  │Movement  │  │LLM       │            │
│  │Recognition│  │Analysis  │  │Service   │            │
│  └────┬─────┘  └────┬─────┘  └────┬─────┘            │
│       │            │            │                      │
└───────┼────────────┼────────────┼──────────────────────┘
        │            │            │
        └────────────┴────────────┘
                    │
                    ▼
        ┌───────────────────────┐
        │   "THE HOLLOW"        │
        │   Response Generation│
        └───────────┬─────────────┘
                    │
                    ▼
        ┌───────────────────────┐
        │   SCREEN DISPLAY      │
        │   Text + Effects     │
        └───────────────────────┘
```

---

## 4. Objectives of the Game

### Main Objective
**Reach the end of the experience** — complete all 8 phases of the game and see the final phrases. However, the game doesn't have an explicit "victory" or "defeat"—it's an experience the player goes through.

### Side Objectives (Optional)
1. **Explore all reactions** — try different actions (speaking, staying silent, moving) and see all possible game reactions
2. **Understand the mechanics** — figure out how the game analyzes player actions through sensors
3. **Experience fully** — don't close the app out of fear, but reach the end
4. **Replay** — play the game multiple times to see different LLM reactions

### What the Player Tries to Achieve
The player doesn't try to "win"—they try to understand what's happening. The game creates a mystery: what is this app? What does it do? Why does it know about my movements and state? The player tries to solve this mystery by going through the experience.

---

## 5. Game Mechanics

### Player Role
**The player is the player themselves.** They don't control a character—they themselves are the character. The game observes the real player through their phone's sensors.

**Number of Players:** 1 (single-player game)

### Characters
**"The Hollow"** — this is not a character in the traditional sense. It's a pattern that emerges from sensory desynchronization. It speaks through text on the screen, using short, mysterious phrases. It has no physical form—it exists only as a sense of presence.

**Characteristics of "The Hollow":**
- Speaks briefly, mysteriously, frighteningly
- Never directly mentions sensors or technical details
- Uses metaphors and hints
- Creates a sense that it knows more than it says
- Reacts to player actions in real time

### Controls / Actions

Main Interactions:
1. Voice — player can say something, game recognizes speech and reacts
2. Movement — player can move the phone, game analyzes movements through gyroscope
3. Touch — player can touch the screen, game reacts with vibration and text
4. Silence — player can stay silent, game comments on silence
5. Proximity — player can bring phone closer to face, game uses proximity sensor

No traditional buttons or menus — interface is minimalistic: only text on screen.

### Rules

What the player can do:
- Say anything
- Move however they want
- Touch the screen
- Stay silent
- Bring phone closer to face
- Close the app at any time

What the player cannot do:
- Control the game through buttons (there are none)
- Skip phases (game progresses by time)
- Save progress (no save system)
- Change settings (minimalistic interface)

How the player "wins":
The player doesn't win in the traditional sense—they experience the experience. "Victory" is reaching the end and seeing the final phrases.

How the player "loses":
The player doesn't lose—they can only close the app out of fear or discomfort.

### Progression System

Temporal Progression:
- Game progresses through 8 phases, each lasting a specific time
- Phases change automatically after time expires

Tension Progression:
- Each subsequent phase creates greater tension than the previous one
- Anomalies appear only in later phases

Interaction Progression:
- Early phases: game only establishes contact
- Middle phases: game begins commenting on player state
- Late phases: game requires physical interaction (proximity)

No traditional levels or upgrades — progression happens through increasing tension and interaction complexity.

### Challenges

Enemies: No traditional enemies—the enemy is the sense of presence itself and paranoia.

Time Limits:** No explicit time limits, but each phase has its own duration.

**Puzzles:** No traditional puzzles—the "puzzle" is understanding what's happening and why the game knows about your actions.

**Resource Management:** No resources to manage—the game uses real data from phone sensors.

**Main Challenge:** Experience the experience without closing the app out of fear or discomfort. The game creates psychological tension through subtle hints and observations.

---

## 6. Possible Endings

### Ending 1: "Full Awareness" (Main)
**Condition:** Player completes all phases to the end without closing the app.

**Description:** Game shows final phrases: "I'm not in the phone. I'm in you. And you know it." Screen slowly darkens, text "We'll return later." appears. App goes to background, creating a sense that "it" continues to exist even after closing the app.

**Emotional Effect:** Player understands that "it" wasn't in the app—it was in their perception. The game makes the player doubt their own reality.

### Ending 2: "Escape" (Alternative)
**Condition:** Player closes the app before completing all phases.

**Description:** If player closes the app, the game "remembers" this. On next launch, the game might say: "You returned. I knew you'd return." Or: "You ran away. But I'm still here."

**Emotional Effect:** Player understands they can't just "escape" the experience—the game creates a sense that "it" continues to exist even after closing.

### Ending 3: "Synchronization" (Hidden)
**Condition:** Player plays the game multiple times, and the game "remembers" their behavior.

**Description:** On repeated playthroughs, the game begins predicting player actions more accurately. It might say: "I knew you'd say that" or "I saw this before. Many times." The game creates a sense that it's not just reacting—it's "remembering" and "learning". This creates a sense that "it" is becoming part of the player.

**Emotional Effect:** Player understands the game doesn't just react—it "remembers" and "learns". This creates a sense that "it" is becoming part of the player.

---

## 7. World of the Game

### Environment Type
**The player's real world** — room, house, any place where the player is. The game doesn't create a virtual world—it uses the player's real world and distorts it through the prism of sensory desynchronization.

### Atmosphere
**Minimalistic, dark, frightening.** The game interface is a black or dark gray background with white text. No bright colors, no complex graphics—only text and a sense of presence.

**Visual Style:**
- Black or dark gray background
- White text that types letter by letter
- Minimalistic interface without buttons and menus
- "Noise" effects to create atmosphere of old video cameras
- Gradients to create depth

**Sound Design:**
- Minimalistic—mostly silence
- Subtle sound effects: whispers, glitch sounds, vibrations
- Echo of player's voice (in anomalies phase)
- Heartbeat rhythm through haptic feedback

### Cultural and Historical Inspiration
The game is inspired by:
- **Scientific research** on sensory desynchronization and phantom interpolation
- **Psychological horror games** (e.g., "Layers of Fear", "PT")
- **AR horror games** (e.g., "Dreadhalls VR")
- **Interactive experiences** (e.g., "Her Story", "The Stanley Parable")
- **Real phenomena** of paranormal perception

### World Lore

**Research History:**
- **2019** — First cases of sensory desynchronization documented in patients after traumatic brain injuries
- **2020** — Prototype app developed for documenting anomalies
- **2021** — Research discontinued due to ethical concerns
- **2022** — App lost, but copies continue to spread

**Scientific Basis (fictional, but plausible):**
Sensory desynchronization is a real phenomenon where the brain incorrectly processes sensory information. When the delay exceeds 200 milliseconds, the brain begins to "fill in the gaps" with its own interpretations—this is called "phantom interpolation".

**"The Hollow":**
This is not a spirit or demon—it's a pattern that emerges when the brain tries to cope with inconsistencies in perception. "The Hollow" uses the user's voice because it's the only "language" the brain can interpret. It reacts to movements because movements are a way to "check reality". It records breathing because breathing is the basic rhythm the brain uses for synchronization.

**Why It's Scary:**
Not because it's supernatural, but because it's really possible. Sensory desynchronization is a real phenomenon. Phantom interpolation is a documented phenomenon. The app uses real phone sensors. The more the player pays attention to the problem, the worse it becomes. Deleting the app won't help—the problem isn't in the app, but in the fact that the player now knows about the problem.

---

## 8. Visual Development (Concept Art & References)

### Character Concept Art

**"The Hollow":**
- Has no physical form—exists only as text on screen
- Visually represented through text style: short phrases, mysterious formulations
- References: minimalistic design from "Her Story", text interfaces from "Doki Doki Literature Club"

### Props and Objects Concept Art

**Game Interface:**
- Minimalistic design: black background, white text
- Text typing effect letter by letter
- References: interfaces from "Papers, Please", minimalistic design from "Limbo"

**Effects:**
- "Noise" in background to create atmosphere of old video cameras
- Gradients to create depth
- Glitch effects for messages with anomalies
- References: visual effects from "Layers of Fear", glitch art from "Pony Island"

### Environment Concept Art

**Environment:**
- Player's real world—room, house, any place
- Game doesn't create virtual environment—it uses the real one
- References: AR horror games that use player's real environment

**Atmosphere:**
- Dark, minimalistic, frightening
- References: atmosphere from "PT", minimalistic design from "Inside"

### Visual Style References

1. **"Her Story"** — minimalistic interface, text interaction
2. **"PT"** — psychological horror atmosphere, sense of presence
3. **"Layers of Fear"** — visual effects, glitch art
4. **"Papers, Please"** — minimalistic interface, text design
5. **"Doki Doki Literature Club"** — using text to create atmosphere
6. **"Inside"** — minimalistic design, dark atmosphere

### Technical Visual Style Details

**Color Palette:**
- Primary color: black (#000000)
- Secondary color: dark gray (#0A0A0A)
- Accent color: white (#FFFFFF)
- Effects: semi-transparent gradients, glitch effects

**Typography:**
- Font: iOS system font (San Francisco)
- Size: 17pt for main text
- Style: regular, rounded

**Animations:**
- Text typing letter by letter (delay 0.05-0.06 seconds per character)
- Smooth text appearance and disappearance
- Glitch effects for messages with anomalies
- Vibrations for haptic feedback

---

## 9. Additional Materials and Recommendations

### Recommendations for Visual Elements in Presentation

**For a complete presentation, it's recommended to add:**

1. **Game Interface Screenshots:**
   - Loading screen with text "wait..."
   - Screen with phrase "Are you there?"
   - Screen with observations ("You're tired", "You're tense")
   - Screen with anomalies (echo, predictions)
   - Final screen with phrase "I'm in you"

2. **Diagrams and Schematics:**
   - Sensor operation diagram (can use real code screenshots)
   - Game phases timeline
   - Player-system interaction diagram (already added above)

3. **Concept Art:**
   - Moodboard with visual references
   - Interface sketches (can use real screenshots)
   - Color palette description with examples

4. **Technical Diagrams:**
   - System architecture (sensors → analysis → LLM → display)
   - LLM service operation diagram
   - Game state diagram (GameStateManager)

### Alternative Approaches and Development Options

**Alternative Approach 1: Multiplayer**
- Game can be adapted for multiple players
- One player becomes "observed", others become "observers"
- Creates additional level of social tension

**Alternative Approach 2: Extended Version with Saves**
- Add save system between sessions
- Game "remembers" previous interactions
- Creates sense of long-term observation

**Alternative Approach 3: VR Version**
- Adaptation for VR headsets
- Using eye tracking and head movement tracking
- Deeper immersion in the experience

**Alternative Approach 4: Web Version**
- Adaptation for web browsers
- Using Web APIs for sensor access
- Wider audience reach

### Potential Risks and Limitations

**Technical Risks:**
1. **Dependency on External APIs** — game uses LLM services that may be unavailable or expensive
2. **Sensor Accuracy** — different iPhone models may have different sensor accuracy
3. **Performance** — real-time data analysis can be resource-intensive

**Design Risks:**
1. **Too Obvious Reactions** — game may become too obvious if reactions are too straightforward
2. **Insufficient Tension** — game may not create enough tension for some players
3. **Repetitiveness** — after first playthrough, game may lose surprise effect

**Ethical Risks:**
1. **Psychological Impact** — game may cause real fear or discomfort in sensitive players
2. **Privacy** — game uses real player data (voice, movements, location)
3. **Addiction** — game may create addiction in some players

**Risk Mitigation Recommendations:**
- Add warnings about psychological impact
- Implement "safe exit" system (easy to close app)
- Ensure transparency in data usage
- Provide option to disable certain sensors

---

**Author:** [Your Name]  
**Date:** [Document Creation Date]  
**Version:** 1.0

