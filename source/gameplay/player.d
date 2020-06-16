module gameplay.player;

import std.variant;

/// Describes who is controlling the player
enum PlayerType {
    User,       // The player is the user of this software (a very cool guy)
    AI,         // The player is an AI
    Network,    // The player is on the network (may be an AI)
    FIBS,
}

/**
 * Contains metadata about a player
 */
struct PlayerMeta {
    /// Full name of the player
    string name;

    /// Username/peer_id/AI id
    string id;

    /// What type of player is this - who's controlling them
    PlayerType type;

    /// General configuration / depends on the type
    Variant config;
}