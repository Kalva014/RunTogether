# RunTogether

<div align="center">

![RunTogether Logo](https://img.shields.io/badge/RunTogether-Social_Running-orange?style=for-the-badge&logo=apple&logoColor=white)

**Your Social Running Companion**

[![iOS](https://img.shields.io/badge/iOS-15.0+-000000?style=flat&logo=apple&logoColor=white)](https://www.apple.com/ios/)
[![Swift](https://img.shields.io/badge/Swift-5.9-FA7343?style=flat&logo=swift&logoColor=white)](https://swift.org)
[![SwiftUI](https://img.shields.io/badge/SwiftUI-3.0-0066CC?style=flat&logo=swift&logoColor=white)](https://developer.apple.com/xcode/swiftui/)
[![License](https://img.shields.io/badge/License-Proprietary-red?style=flat)](LICENSE)

</div>

---

## 📱 What is RunTogether?

**RunTogether** is a competitive multiplayer running app that transforms solo runs into social experiences. Race against friends and runners worldwide in real-time, climb the ranked ladder, and track your progress with beautiful 3D avatars in a Zwift-inspired running environment.

### Key Features

- 🏃 **Real-Time Multiplayer Racing** - Compete with up to 8 runners simultaneously
- 🎮 **3D Avatar System** - Watch your character run alongside others in a live scene
- 🏆 **Ranked Competitive Mode** - Climb from Bronze to Champion with LP-based progression
- 👥 **Social Features** - Add friends, create run clubs, and compete on leaderboards
- 📊 **Advanced Tracking** - GPS distance, pace, heart rate, and race statistics
- 💰 **Premium Subscriptions** - Weekly, monthly, and yearly plans via RevenueCat
- 🎨 **Customizable Sprites** - Choose from multiple running avatars

---

## 🎯 How It Works

### Overview

RunTogether combines real-time GPS tracking, multiplayer synchronization, and competitive gaming mechanics to create an engaging social running experience. Here's how each component works together:

### 🏃 Real-Time Multiplayer Racing

**The Experience:**
When you start a race, you see up to 8 animated avatars running together on a 3D track. Each avatar represents a real person running in the real world, with their position updated in real-time based on GPS data.

**The Technology:**
- **GPS Tracking**: CoreLocation monitors your position, speed, and distance every second
- **Realtime Sync**: Supabase Realtime Channels broadcast your position to all race participants
- **SpriteKit Rendering**: 3D avatars animate smoothly based on incoming position data
- **Sub-second Updates**: Race positions update multiple times per second for fluid gameplay

**How It Works:**
1. User joins or creates a race lobby
2. App subscribes to race-specific Realtime channel
3. During the race, GPS data is sent to Supabase every 1-2 seconds
4. All participants receive position updates via WebSocket
5. SpriteKit scene updates avatar positions and animations
6. Race ends when all participants finish or time expires

### 🎮 3D Avatar System

**Visual Experience:**
Each runner is represented by a customizable 2D sprite character that runs on a parallax-scrolling track. The scene includes:
- **Dynamic positioning** based on relative race progress
- **Smooth animations** (running, idle, finishing)
- **Username labels** floating above each avatar
- **Distance markers** showing progress
- **Pace indicators** with color coding (fast = green, slow = red)

**Technical Implementation:**
- **SpriteKit Scenes**: Three scene types (Casual, Race, Solo)
- **Sprite Manager**: Handles sprite selection and loading
- **Character Models**: Store sprite URLs and animation states
- **Real-time Updates**: Position calculations based on distance covered
- **Parallax Background**: Creates depth and motion illusion

### 🏆 Competitive Ranking System

**League Points (LP) Mechanics:**
RunTogether uses a sophisticated ranking system inspired by competitive games like League of Legends:

**Rank Progression:**
- Start at **Bronze IV** with 0 LP
- Gain LP by finishing races (1st = +25 LP, 8th = -10 LP)
- Reach 100 LP → **Promote** to next division/tier
- Drop below 0 LP → **Demote** to previous division/tier
- Climb through 6 tiers: Bronze → Silver → Gold → Platinum → Diamond → Champion

**Matchmaking Algorithm:**
```
1. Find races matching your distance preference
2. Filter by rank tier (±1 tier, expandable to ±2)
3. Check race age (max 5 minutes old)
4. Validate all participants are within rank range
5. Join race or create new one if no matches
```

**LP Calculation:**
```swift
// Dynamic LP based on placement and lobby size
Base LP = (-18 to +28) * lobby_size_multiplier
+ Win bonus (+2 for 1st, +1 for 2nd)
- Last place penalty (-1 for consistent losses)
```

**Database Integration:**
- `Ranked_Profiles` table stores tier, division, LP, MMR
- Automatic rank updates after each race completion
- Leaderboard queries sorted by tier → division → LP
- Historical stats (total races, top 3 finishes, win rate)

### 👥 Social Features

**Friends System:**
- **Friend Requests**: Send/accept/reject via `Friendships` table
- **Friend Leaderboards**: Compare stats with friends only
- **Profile Viewing**: See friends' ranks, stats, and recent races
- **Friend Notifications**: Get notified when friends start races

**Run Clubs:**
- **Create Groups**: Organize running communities
- **Club Leaderboards**: Compete within your club
- **Member Management**: Invite/remove members
- **Club Stats**: Aggregate distance, races, achievements

**Leaderboards:**
- **Global Ranked**: Top players by LP across all tiers
- **Friends Only**: Your position among friends
- **Casual Stats**: Total distance, races completed, average pace
- **Real-time Updates**: Positions update as races complete

### 📊 Advanced Tracking

**GPS & Location:**
- **CoreLocation Framework**: Continuous background location tracking
- **Distance Calculation**: Haversine formula for accurate GPS distance
- **Pace Monitoring**: Real-time pace calculation (min/mile or min/km)
- **Route Recording**: Store GPS coordinates for race replay

**Health Integration:**
- **HealthKit Framework**: Access heart rate data during runs
- **Live Heart Rate**: Display BPM in real-time during races
- **Workout Sessions**: Create HKWorkoutSession for accurate tracking
- **Calorie Estimation**: Based on distance, pace, and heart rate

**Statistics Tracking:**
- **Race Stats**: Distance, time, pace, placement, LP change
- **Personal Records**: Fastest mile, longest run, best rank
- **Historical Data**: All races stored in `Race_Participants` table
- **Progress Charts**: Visualize improvement over time

### 💰 Subscription System

**Monetization Model:**
RunTogether uses a freemium subscription model with three tiers:

| Tier | Price | Features |
|------|-------|----------|
| **Free** | $0 | Limited races per day, ads, basic features |
| **Weekly** | $4.99/week | Unlimited races, no ads, premium avatars |
| **Monthly** | $14.99/month | All weekly features + exclusive content |
| **Yearly** | $49.99/year | Best value (67% savings) + early access |

**Payment Flow:**
1. **Subscription Gate**: Users see paywall after signup
2. **7-Day Free Trial**: New users get full access for 7 days
3. **RevenueCat Integration**: Handles purchase, validation, receipt
4. **StoreKit 2**: Modern Apple payment processing
5. **Cross-Device Sync**: Subscription follows user across devices
6. **Restore Purchases**: Users can restore on new devices

**Technical Implementation:**
- **RevenueCat SDK**: Manages subscriptions, trials, renewals
- **Entitlements**: Single "premium" entitlement for all paid tiers
- **Receipt Validation**: Server-side validation via RevenueCat
- **Subscription Status**: Synced to Supabase for backend checks
- **Paywall UI**: Beautiful native SwiftUI subscription screen

### 🔄 Real-Time Synchronization

**Supabase Realtime:**
RunTogether uses Supabase's Realtime engine for instant updates:

**Race Channels:**
```swift
// Subscribe to race-specific channel
let channel = supabase.realtime.channel("race:\(raceId)")
await channel.on(.postgres_changes) { change in
    // Update race participant positions
    updateAvatarPosition(change.new)
}
```

**What Gets Synced:**
- **Position Updates**: Every participant's distance and pace
- **Race Status**: Start, finish, cancellation events
- **Chat Messages**: In-race communication (future feature)
- **Leaderboard Changes**: Live ranking updates

**Performance Optimization:**
- **Throttling**: Limit updates to 2 per second per user
- **Delta Updates**: Only send changed data, not full state
- **Channel Cleanup**: Unsubscribe when race ends
- **Reconnection Logic**: Auto-reconnect on network issues

### 🔐 Authentication & Security

**User Authentication:**
- **Supabase Auth**: Email/password authentication
- **JWT Tokens**: Secure session management
- **Password Reset**: Email-based password recovery with deep links
- **Row Level Security**: Database policies enforce user permissions

**Data Security:**
- **API Keys**: Stored in Xcode Build Settings (not in code)
- **Environment Variables**: Separate dev/prod configurations
- **HTTPS Only**: All API calls encrypted
- **User Isolation**: RLS policies prevent unauthorized data access

### 🎨 User Experience

**Onboarding Flow:**
1. **Welcome Screen**: Brand introduction
2. **Sign Up/Login**: Quick authentication
3. **Subscription Gate**: 7-day trial offer
4. **Avatar Selection**: Choose your running character
5. **Tutorial**: Learn how to start races
6. **First Race**: Guided casual race experience

**Main App Flow:**
1. **Home Tabs**: Run, Friends, Leaderboard, Groups, Profile
2. **Start Race**: Choose casual or ranked, set distance
3. **Matchmaking**: Find or create race lobby
4. **Pre-Race**: 10-second countdown with participants
5. **Live Race**: Run with real-time avatar updates
6. **Post-Race**: Results, stats, LP changes, share options

**UI/UX Design:**
- **Dark Theme**: Easy on eyes during outdoor runs
- **Large Touch Targets**: Easy to tap while running
- **Minimal Distractions**: Focus on the race
- **Audio Feedback**: Sound effects for actions
- **Haptic Feedback**: Vibrations for important events
- **Portrait Lock**: Prevents accidental rotation

### 🔧 Background Processing

**Continuous Tracking:**
- **Background Location**: Tracks GPS even when app is backgrounded
- **Background Fetch**: Syncs race data periodically
- **Remote Notifications**: Push alerts for race events
- **Battery Optimization**: Intelligent GPS sampling to save power

**Data Persistence:**
- **Local Caching**: Store race data locally during poor connectivity
- **Sync Queue**: Upload cached data when connection restored
- **Offline Mode**: Continue tracking even without internet
- **Conflict Resolution**: Handle simultaneous updates gracefully

---

## 🏗️ Architecture

### Tech Stack

| Component | Technology |
|-----------|-----------|
| **Frontend** | SwiftUI 3.0 |
| **Backend** | Supabase (PostgreSQL + Realtime) |
| **Authentication** | Supabase Auth |
| **Payments** | RevenueCat + StoreKit 2 |
| **Location** | CoreLocation + HealthKit |
| **3D Graphics** | SpriteKit |
| **Real-time Sync** | Supabase Realtime Channels |

### Project Structure

```
RunTogether/
├── Features/
│   ├── Auth/              # Login, signup, password reset
│   ├── Onboarding/        # First-time user experience
│   ├── Home/              # Main tabs (Run, Friends, Leaderboard, Groups, Profile)
│   ├── Running/           # Live race scenes, tracking, results
│   ├── Details/           # Profile and group detail views
│   ├── Settings/          # App settings and preferences
│   └── Subscription/      # Paywall and subscription management
├── Services/
│   ├── SupabaseConnection.swift    # Database & auth
│   ├── SubscriptionManager.swift   # RevenueCat integration
│   ├── LocationManager.swift       # GPS tracking
│   ├── HealthKitManager.swift      # Heart rate data
│   ├── SoundManager.swift          # Audio feedback
│   └── SpriteManager.swift         # Avatar management
└── Utilities/             # Helpers, extensions, constants
```

---

## 🚀 Getting Started

### Prerequisites

- **Xcode 15.0+** (macOS Ventura or later)
- **iOS 15.0+** deployment target
- **Apple Developer Account** (for testing on device)
- **Supabase Account** ([app.supabase.com](https://app.supabase.com))
- **RevenueCat Account** ([app.revenuecat.com](https://app.revenuecat.com))

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/yourusername/RunTogether.git
   cd RunTogether
   ```

2. **Open in Xcode**
   ```bash
   open RunTogether.xcodeproj
   ```

3. **Configure Build Settings**
   
   Navigate to **Xcode → Project → Build Settings → User-Defined**
   
   Add the following environment variables:
   
   | Key | Value | Description |
   |-----|-------|-------------|
   | `SUPABASE_URL` | `https://your-project.supabase.co` | Your Supabase project URL |
   | `SUPABASE_KEY` | `your-anon-key` | Your Supabase anon/public key |
   | `REVENUECAT_KEY` | `appl_xxxxxxxxxx` | Your RevenueCat API key (must start with `appl_`) |

   > ⚠️ **Important**: Never commit these keys to version control. Use Xcode's build settings.

4. **Configure Info.plist**
   
   The `Info.plist` references these build settings:
   ```xml
   <key>Supabase URL</key>
   <string>$(SUPABASE_URL)</string>
   <key>Supabase Key</key>
   <string>$(SUPABASE_KEY)</string>
   <key>RevenueCat API Key</key>
   <string>$(REVENUECAT_KEY)</string>
   ```

5. **Build and Run**
   - Select your target device or simulator
   - Press `⌘ + R` to build and run

---

## 🗄️ Database Setup

### Supabase Configuration

RunTogether uses Supabase for backend services. You'll need to create the following tables:

#### Required Tables

1. **Profiles** - User profile information
   ```sql
   CREATE TABLE Profiles (
     id UUID PRIMARY KEY REFERENCES auth.users(id),
     created_at TIMESTAMPTZ DEFAULT NOW(),
     username TEXT UNIQUE NOT NULL,
     first_name TEXT,
     last_name TEXT,
     location TEXT,
     country TEXT,
     profile_picture_url TEXT,
     selected_sprite_url TEXT
   );
   ```

2. **Races** - Race sessions
   ```sql
   CREATE TABLE Races (
     id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
     name TEXT,
     mode TEXT NOT NULL, -- 'casual' or 'ranked'
     start_time TIMESTAMPTZ NOT NULL,
     end_time TIMESTAMPTZ,
     distance DOUBLE PRECISION NOT NULL,
     use_miles BOOLEAN DEFAULT true
   );
   ```

3. **Race_Participants** - Race participation records
   ```sql
   CREATE TABLE Race_Participants (
     id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
     created_at TIMESTAMPTZ DEFAULT NOW(),
     race_id UUID REFERENCES Races(id) ON DELETE CASCADE,
     user_id UUID REFERENCES Profiles(id),
     finish_time TEXT,
     distance_covered DOUBLE PRECISION DEFAULT 0,
     place INTEGER,
     average_pace DOUBLE PRECISION
   );
   ```

4. **Ranked_Profiles** - Ranking system data
   ```sql
   CREATE TABLE Ranked_Profiles (
     id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
     user_id UUID UNIQUE REFERENCES Profiles(id),
     rank_tier TEXT DEFAULT 'Bronze',
     rank_division INTEGER DEFAULT 4,
     league_points INTEGER DEFAULT 0,
     hidden_mmr INTEGER DEFAULT 1000,
     top_3_finishes INTEGER DEFAULT 0,
     total_races INTEGER DEFAULT 0,
     created_at TIMESTAMPTZ DEFAULT NOW(),
     updated_at TIMESTAMPTZ DEFAULT NOW()
   );
   ```

5. **Friendships** - Friend connections
   ```sql
   CREATE TABLE Friendships (
     id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
     created_at TIMESTAMPTZ DEFAULT NOW(),
     user_id UUID REFERENCES Profiles(id),
     friend_id UUID REFERENCES Profiles(id),
     status TEXT DEFAULT 'pending', -- 'pending', 'accepted', 'rejected'
     UNIQUE(user_id, friend_id)
   );
   ```

6. **Run_Clubs** - Social running groups
   ```sql
   CREATE TABLE Run_Clubs (
     id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
     created_at TIMESTAMPTZ DEFAULT NOW(),
     name TEXT NOT NULL,
     description TEXT,
     creator_id UUID REFERENCES Profiles(id),
     member_count INTEGER DEFAULT 1
   );
   ```

#### Storage Buckets

Create the following storage buckets in Supabase:

- **profile-pictures** - User profile images (public read access)

#### Realtime Configuration

Enable Realtime for these tables:
- `Race_Participants` - For live race updates
- `Races` - For race status changes

---

## 💳 Payment System

### RevenueCat Setup

1. **Create RevenueCat Account**
   - Sign up at [app.revenuecat.com](https://app.revenuecat.com)
   - Create a new project

2. **Configure App Store Connect**
   - Link your App Store Connect account
   - Import your in-app purchases

3. **Create Products**
   
   Create the following subscription products in App Store Connect:
   
   | Product ID | Type | Price | Description |
   |------------|------|-------|-------------|
   | `runtogether_weekly` | Auto-renewable | $4.99/week | Weekly Premium |
   | `runtogether_monthly` | Auto-renewable | $14.99/month | Monthly Premium |
   | `runtogether_yearly` | Auto-renewable | $49.99/year | Yearly Premium |

4. **Configure Entitlements**
   
   In RevenueCat dashboard:
   - Create entitlement: `premium`
   - Attach all three products to this entitlement

5. **Get API Key**
   - Copy your **Public App-Specific API Key** (starts with `appl_`)
   - Add to Xcode Build Settings as `REVENUECAT_KEY`

### Testing Subscriptions

1. **StoreKit Configuration File**
   - The project includes `RunTogether.storekit` for local testing
   - Xcode automatically uses this for simulator testing

2. **Sandbox Testing**
   - Create sandbox test accounts in App Store Connect
   - Use these accounts to test real purchases on device

3. **Test Mode**
   - RevenueCat automatically detects sandbox environment
   - All test purchases are free and don't charge real money

### Subscription Features

- ✅ **7-day free trial** for new users
- ✅ **Automatic renewal** managed by Apple
- ✅ **Restore purchases** functionality
- ✅ **Cross-device sync** via RevenueCat
- ✅ **Subscription management** via App Store

---

## 🏆 Ranking System

### How Rankings Work

RunTogether uses a **League Points (LP)** system similar to competitive games:

#### Rank Tiers

| Tier | Divisions | Description |
|------|-----------|-------------|
| 🥉 **Bronze** | IV, III, II, I | Rookies finding their stride |
| 🥈 **Silver** | IV, III, II, I | Developing runners building consistency |
| 🥇 **Gold** | IV, III, II, I | Competitive athletes chasing podiums |
| 💠 **Platinum** | IV, III, II, I | Elite runners with precision pacing |
| 💎 **Diamond** | IV, III, II, I | Top-tier competitors dominating races |
| 👑 **Champion** | None | Legendary status - LP fuels global leaderboard |

#### LP Distribution

Finishing position determines LP gain/loss:

- **1st place**: +25 to +28 LP
- **2nd place**: +15 to +20 LP
- **3rd place**: +10 to +15 LP
- **4th-5th**: +5 to +10 LP
- **6th-7th**: 0 to +5 LP
- **8th+**: -5 to -18 LP

#### Promotion & Demotion

- **Promotion**: Reach 100 LP → advance to next division/tier
- **Demotion**: Drop below 0 LP → fall to previous division/tier
- **Protection**: Cannot fall below Bronze IV

#### Matchmaking

- Players matched within **±1 tier** (expandable to ±2 if no matches)
- Champion tier can match with Diamond
- Race lobbies support 2-8 players

### Using the Ranking System

For detailed API documentation, see [RANKING_API_REFERENCE.md](RANKING_API_REFERENCE.md)

**Quick Examples:**

```swift
// Get user's rank
let profile = try await supabaseConnection.getRankedProfile()
print(profile?.displayString) // "Gold II — 64 LP"

// Update rank after race
let result = try await supabaseConnection.updateRankAfterRace(
    userId: userId,
    place: 1,
    totalRunners: 8
)
print(result.displayMessage) // "Promoted to Gold I! (+25 LP)"

// Find ranked matches
let races = try await supabaseConnection.findRankedMatches(
    mode: "ranked",
    distance: 1609.34,
    useMiles: true,
    maxSpread: 1
)
```

---

## 👥 User Management

### Managing User Data

#### Via Supabase Dashboard

1. **View Users**
   - Navigate to **Authentication → Users**
   - See all registered users and their metadata

2. **Edit Profiles**
   - Go to **Table Editor → Profiles**
   - Directly edit user profile data

3. **Manage Rankings**
   - Go to **Table Editor → Ranked_Profiles**
   - Manually adjust LP, tier, or division for specific users

#### Via SQL Editor

```sql
-- Update user's rank
UPDATE Ranked_Profiles
SET rank_tier = 'Gold',
    rank_division = 2,
    league_points = 50
WHERE user_id = 'user-uuid-here';

-- Reset user's rank
UPDATE Ranked_Profiles
SET rank_tier = 'Bronze',
    rank_division = 4,
    league_points = 0,
    top_3_finishes = 0,
    total_races = 0
WHERE user_id = 'user-uuid-here';

-- View top ranked players
SELECT p.username, rp.rank_tier, rp.rank_division, rp.league_points
FROM Ranked_Profiles rp
JOIN Profiles p ON rp.user_id = p.id
ORDER BY 
  CASE rp.rank_tier
    WHEN 'Champion' THEN 5
    WHEN 'Diamond' THEN 4
    WHEN 'Platinum' THEN 3
    WHEN 'Gold' THEN 2
    WHEN 'Silver' THEN 1
    ELSE 0
  END DESC,
  rp.rank_division ASC,
  rp.league_points DESC
LIMIT 10;
```

#### Programmatic Updates

```swift
// Update user profile
try await supabaseConnection.updateProfile(
    username: "newUsername",
    firstName: "John",
    lastName: "Doe",
    location: "San Francisco",
    country: "USA"
)

// Update profile picture
let imageData = profileImage.jpegData(compressionQuality: 0.8)
let url = try await supabaseConnection.uploadProfilePicture(imageData: imageData)
try await supabaseConnection.updateProfile(profilePictureUrl: url)
```

### User Permissions

Configure Row Level Security (RLS) in Supabase:

```sql
-- Users can only update their own profile
CREATE POLICY "Users can update own profile"
ON Profiles FOR UPDATE
USING (auth.uid() = id);

-- Users can view all profiles
CREATE POLICY "Profiles are viewable by everyone"
ON Profiles FOR SELECT
USING (true);

-- Users can only update their own ranked profile
CREATE POLICY "Users can update own ranked profile"
ON Ranked_Profiles FOR UPDATE
USING (auth.uid() = user_id);
```

---

## 🎮 Race Modes

### Casual Mode

- **No rank impact** - Just for fun
- **Any distance** - Set custom race lengths
- **Flexible matchmaking** - Join any available race
- **Practice mode** - Perfect for testing or warming up

### Ranked Mode

- **Competitive** - LP gains/losses based on placement
- **Skill-based matchmaking** - Match with similar ranks
- **Standard distances** - 1 mile, 5K, 10K
- **Leaderboard tracking** - Climb the global rankings

### Creating a Race

```swift
// Create casual race
let race = try await supabaseConnection.createRace(
    name: "Morning Run",
    mode: "casual",
    start_time: Date(),
    distance: 1609.34, // 1 mile in meters
    useMiles: true
)

// Create ranked race
let rankedRace = try await supabaseConnection.createRankedRace(
    name: "Ranked 5K",
    mode: "ranked",
    start_time: Date(),
    distance: 5000.0,
    useMiles: false
)
```

---

## 📊 Analytics & Monitoring

### RevenueCat Dashboard

Monitor subscription metrics:
- **Active subscriptions**
- **Monthly Recurring Revenue (MRR)**
- **Churn rate**
- **Trial conversions**
- **Revenue by product**

### Supabase Dashboard

Track app usage:
- **Active users** (via Auth dashboard)
- **Database queries** (via Logs)
- **API usage** (via Settings → Usage)
- **Realtime connections** (via Realtime inspector)

### Custom Analytics

Add analytics to track:
- Race completions
- Average race distance
- User retention
- Feature usage

---

## 🔧 Configuration

### Environment Variables

All sensitive configuration is stored in Xcode Build Settings:

```
SUPABASE_URL=https://xxxxx.supabase.co
SUPABASE_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
REVENUECAT_KEY=appl_xxxxxxxxxxxxxxxxx
```

### App Permissions

Required permissions in `Info.plist`:

| Permission | Usage |
|------------|-------|
| `NSLocationWhenInUseUsageDescription` | GPS tracking during runs |
| `NSHealthShareUsageDescription` | Heart rate monitoring |
| `NSPhotoLibraryUsageDescription` | Profile picture uploads |

### Background Modes

Enabled background modes:
- **Location updates** - Continue tracking during runs
- **Remote notifications** - Push notifications
- **Background fetch** - Sync race data

---

## 🐛 Troubleshooting

### Common Issues

#### 1. RevenueCat API Key Error

**Error**: `❌ RevenueCat API Key not found in Info.plist`

**Solution**:
- Ensure `REVENUECAT_KEY` is set in Build Settings
- Key must start with `appl_` (not `test_`)
- Clean build folder (`⌘ + Shift + K`) and rebuild

#### 2. Supabase Connection Failed

**Error**: `Supabase URL or Key not found in Info.plist`

**Solution**:
- Verify `SUPABASE_URL` and `SUPABASE_KEY` in Build Settings
- Check that URL includes `https://`
- Ensure anon key is correct (not service role key)

#### 3. Subscription Not Working

**Symptoms**: Prices show as $0.00 or purchases fail

**Solution**:
- Verify products exist in App Store Connect
- Check RevenueCat dashboard for product configuration
- Ensure entitlement ID matches (`premium`)
- Test with sandbox account on physical device

#### 4. GPS Tracking Issues

**Symptoms**: Location not updating during run

**Solution**:
- Grant location permissions in Settings
- Test on physical device (simulator has limited GPS)
- Ensure background location is enabled
- Check that device has GPS signal

#### 5. Realtime Updates Not Working

**Symptoms**: Race updates not appearing live

**Solution**:
- Enable Realtime on tables in Supabase dashboard
- Check network connection
- Verify channel subscription in code
- Review Supabase Realtime logs

---

## 🚢 Deployment

### App Store Submission

1. **Update Version & Build Number**
   - Increment in Xcode project settings
   - Follow semantic versioning (e.g., 1.0.0)

2. **Configure App Store Connect**
   - Create app listing
   - Add screenshots and descriptions
   - Set pricing and availability

3. **Submit for Review**
   - Archive app (`Product → Archive`)
   - Upload to App Store Connect
   - Submit for review

### Production Checklist

- [ ] Replace test API keys with production keys
- [ ] Set RevenueCat log level to `.info`
- [ ] Configure production Supabase project
- [ ] Test all subscription flows
- [ ] Verify push notifications
- [ ] Test on multiple devices
- [ ] Review privacy policy
- [ ] Add App Store screenshots
- [ ] Write release notes

---

## 📚 Additional Resources

### Documentation

- [Supabase Documentation](https://supabase.com/docs)
- [RevenueCat Documentation](https://docs.revenuecat.com)
- [Apple HealthKit Guide](https://developer.apple.com/documentation/healthkit)
- [SwiftUI Documentation](https://developer.apple.com/documentation/swiftui)

### API References

- [Ranking System API](RANKING_API_REFERENCE.md) - Complete ranking system documentation
- [Supabase Swift Client](https://github.com/supabase-community/supabase-swift)
- [RevenueCat Swift SDK](https://github.com/RevenueCat/purchases-ios)

### Support

For issues or questions:
- Check the [Troubleshooting](#-troubleshooting) section
- Review API documentation
- Contact the development team

---

## 📄 License

This project is proprietary software. All rights reserved.

---

## 🙏 Acknowledgments

Built with:
- [Supabase](https://supabase.com) - Backend infrastructure
- [RevenueCat](https://revenuecat.com) - Subscription management
- [SwiftUI](https://developer.apple.com/xcode/swiftui/) - Modern UI framework

---

<div align="center">

**RunTogether** - Run together, compete together, win together 🏃‍♂️🏆

Made with ❤️ for runners everywhere

</div>
