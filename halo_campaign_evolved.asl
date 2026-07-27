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
    int         tick        : "HaloSimulation_tag_release.dll", 0x12954A8, 0x0;
    float       xpos        : "HaloSimulation_tag_release.dll", 0x1A5DC30;
    float       ypos        : "HaloSimulation_tag_release.dll", 0x1A5DC34;
    float       zpos        : "HaloSimulation_tag_release.dll", 0x1A5DC38;
    byte        cutscene    : "HaloSimulation_tag_release.dll", 0xA2C3C1;           // 0 = cutscene, 1 = gameplay; aligned to 0xA2C3C0
    int         bsp         : "HaloSimulation_tag_release.dll", 0x9A24D8;
}

startup {
    vars.dirtybsps = new List<int>();

    vars.aslName = "CER Auto Splitter";
	if(timer.CurrentTimingMethod == TimingMethod.RealTime)
	{
		var timingMessage = MessageBox.Show(
			"This game uses Game Time (time without loads) as the main timing method. "+
			"LiveSplit is currently set to show Real Time (time INCLUDING loads). "+
			"Would you like the timing method to be set to Game Time for you?",
			vars.aslName+" | LiveSplit",
			MessageBoxButtons.YesNo,MessageBoxIcon.Question
		);
		if (timingMessage == DialogResult.Yes)
		{
			timer.CurrentTimingMethod = TimingMethod.GameTime;
		}
	}

    settings.Add("il_mode", false, "Individual Level Mode");
    settings.Add("bsp_split", false, "Split on BSP Change");
    settings.Add("cutscene_split", false, "Split on Mid-level Cutscenes");
}

start {
    vars.dirtybsps.Clear();

    return current.loadState == 4       // wait until in game
        && current.tick != old.tick     // wait until out of cutscene
        && current.tick > 3             // wait until out of cutscene
        && current.cutscene == 1        // wait until out of cutscene
        && current.tick < 30            // only start in first half second
        ;
}

reset {
    return current.tick < 3;
}

split {
    if (settings["il_mode"]) {
        if (current.level == "levels\\halo1\\solo\\a15\\a15" && current.cutscene == 0 && current.bsp == 3) {
            return true;
        }
        if (current.level == "levels\\halo1\\solo\\a30\\a30" && current.cutscene == 0 && current.bsp == 2) {
            return true;
        }
        // if (current.level == "levels\\halo1\\solo\\a50\\a50" && current.cutscene == 0 && current.bsp == 5) {
        //     return true;
        // }
        if (current.level == "levels\\halo1\\solo\\b30\\b30" && current.cutscene == 0 && current.bsp == 1) {
            return true;
        }
    }

    if (settings["cutscene_split"] && current.cutscene == 0 && current.cutscene != old.cutscene && current.tick > 60) {
        return true;
    }

    if (settings["bsp_split"] && current.bsp != old.bsp && vars.dirtybsps.Contains(current.bsp) == false) {
        vars.dirtybsps.Add(current.bsp);
        return true;
    }
    if (current.level == "levels\\halo1\\solo\\d40\\d40" && current.bsp == 3 && current.cutscene == 0) {
        return true;
    }

    if (old.level != current.level) {
        vars.dirtybsps.Clear();
        return true;
    }
}

isLoading {
    return current.loadState != 4;
}