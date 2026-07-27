// Halo: Campaign Evolved Auto Splitter
// by Xero

// Build 2026.06.26.1097863 (23 July Pre-release)
/*
Below are a variety of static addresses I found that can be useful for different behaviors. I'm probably overcomplicating, but see some explanation below.
I wanted to include all of these in case the community decides to add timing for main menu, while S&Q, or to remove timing on main menu only on first launch.

Launch      - Value while in main menu immediately when launching the game
Load        - Value while in a load screen
In Game     - Value while in game (includes cutscenes)
S&Q         - Value while saving & quitting, returning to main menu (no load screen)
Main Menu   - Value while in main menu after launch

Address                                 Launch  Load    In Game     S&Q     Main Menu
HaloSimulation_tag_release.dll+CA3844   0       3       4           0       0
HaloSimulation_tag_release.dll+CA3FA0   0       196608  0           0       0
HaloSimulation_tag_release.dll+CA5E7C   0       3       4           0       0
HaloSimulation_tag_release.dll+D5DD10   0       0       1           0       0               Strange behavior near cutscenes
HaloSimulation_tag_release.dll+D5DD20   0       0       65536       65536   0
HaloSimulation_tag_release.dll+CA3F1C   0       0       4294967295  Same    Same
HaloSimulation_tag_release.dll+CA428C   0       3       4           4       4


Various map pointers
HaloSimulation_tag_release.dll+CA3F20
HaloSimulation_tag_release.dll+135853C
HaloSimulation_tag_release.dll+13772D8
HaloSimulation_tag_release.dll+137742C
HaloSimulation_tag_release.dll+13B579C
HaloSimulation_tag_release.dll+14EE7D8
HaloSimulation_tag_release.dll+18324B0

Map Names
e10     Boarding Action                 levels\halo1\solo\extra\e10\e10
e20     The Most Dangerous Game         levels\halo1\solo\extra\e20\e20
e30     Heavy Burden                    levels\halo1\solo\extra\e30\e30

a15     Pillar of Autumn                levels\halo1\solo\a15\a15
a30     Halo                            levels\halo1\solo\a30\a30
a50     The Truth and Reconciliation    levels\halo1\solo\a50\a50
d40     The Maw                         levels\halo1\solo\d40\d40

Tick Counter:
Pointer at "HaloSimulation_tag_release.dll"+012954A8, offset 0

Helper: always increases when in game, count is stuck to 3 in level beginning cutscences

xyz pointers are stable but can tick to other things intermittently during gameplay; just used to end the splits
*/

state("HaloCampaignEvolved") {
    int         loadState   : "HaloSimulation_tag_release.dll", 0xCA3844;
    string32    level       : "HaloSimulation_tag_release.dll", 0xCA3F20;
    int         tick        : "HaloSimulation_tag_release.dll", 0x012954A8, 0x0;
    float       xpos        : "HaloSimulation_tag_release.dll", 0x1A5DC30;
    float       ypos        : "HaloSimulation_tag_release.dll", 0x1A5DC34;
    float       zpos        : "HaloSimulation_tag_release.dll", 0x1A5DC38;
    long        cutscene    : 0xD5B9C90;                                            // = 4294967295 // 0xFFFFFFFF when in any cutscene
}

start {
    return current.loadState == 4                               // wait until in game
        && (current.tick > 3 && current.tick < 30)              // brute force to start timer in the first half second
        ;
}

reset {
    return (current.level == "levels\\halo1\\solo\\a15\\a15" && current.tick <= 3);
}

split {
    // if (current.level == "levels\\halo1\\solo\\d40\\d40" && current.cutscene == 0xFFFFFFFF) {
    //     return true;
    //  }

    return old.level != current.level;
}

isLoading {
    return current.loadState != 4;
}