// Halo: Campaign Evolved Auto Splitter
// by Xero

/*
Map Names
e10     Boarding Action                 levels\halo1\solo\extra\e10\e10
e20     The Most Dangerous Game         levels\halo1\solo\extra\e20\e20
e30     Heavy Burden                    levels\halo1\solo\extra\e30\e30

a15     Pillar of Autumn                levels\halo1\solo\a15\a15
a30     Halo                            levels\halo1\solo\a30\a30
a50     The Truth and Reconciliation    levels\halo1\solo\a50\a50
d40     The Maw                         levels\halo1\solo\d40\d40

Helper: always increases when in game, count is stuck to 3 in level beginning cutscences
*/

state("HaloCampaignEvolved", "2026.07.25.1112544.4-Rel-i343-Meteorite-2607-CU3") {
    int         loadState   : "HaloSimulation_tag_release.dll", 0xCA2824;
    string32    level       : "HaloSimulation_tag_release.dll", 0xCA2F00;
    int         tick        : "HaloSimulation_tag_release.dll", 0x12944C8, 0x0;
    byte        cutscene    : "HaloSimulation_tag_release.dll", 0xA2B3B1;           // 0 = cutscene, 1 = gameplay; aligned to 0xA2C3C0
    byte        paused      : 0xD3A5ED8, 0x618;                                     // 0 = unpaused, 1 = paused
    int         bsp         : "HaloSimulation_tag_release.dll", 0x9A14E0;
    float       x           : "HaloSimulation_tag_release.dll", 0x1294420, 0x2C;
    float       y           : "HaloSimulation_tag_release.dll", 0x1294420, 0x30;
    float       z           : "HaloSimulation_tag_release.dll", 0x1294420, 0x34;
}

state("HaloCampaignEvolved", "2026.06.26.1097863.1-Rel-i343-Meteorite-2606-CU2") {
    int         loadState   : "HaloSimulation_tag_release.dll", 0xCA3844;
    string32    level       : "HaloSimulation_tag_release.dll", 0xCA3F20;
    int         tick        : "HaloSimulation_tag_release.dll", 0x12954A8, 0x0;
    byte        cutscene    : "HaloSimulation_tag_release.dll", 0xA2C3C1;           // 0 = cutscene, 1 = gameplay; aligned to 0xA2C3C0
    byte        paused      : 0xD3ACED8, 0x618;                                     // 0 = unpaused, 1 = paused
    int         bsp         : "HaloSimulation_tag_release.dll", 0x9A24D8;
    float       x           : "HaloSimulation_tag_release.dll", 0x1295400, 0x2C;
    float       y           : "HaloSimulation_tag_release.dll", 0x1295400, 0x30;
    float       z           : "HaloSimulation_tag_release.dll", 0x1295400, 0x34;
}

startup {
    vars.end = false;
    vars.forceIsLoading = false;

    vars.dirtybsps = new List<int>();
    vars.dirtybsps.Add(0); // add 0 to the list so that reverts to bsp 0 don't trigger a split

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

init
{
    version = modules.First().FileVersionInfo.ProductVersion;
}

update
{
    if (
        (current.level == "levels\\halo1\\solo\\a15\\a15" && current.cutscene == 0 && current.bsp == 3) ||
        (current.level == "levels\\halo1\\solo\\a30\\a30" && current.cutscene == 0 && current.bsp == 2) ||
        (current.level == "levels\\halo1\\solo\\a30\\a30" && current.cutscene == 0 && current.bsp == 2) ||
        (current.level == "levels\\halo1\\solo\\a50\\a50" && current.cutscene == 0 && current.bsp == 5 && current.x > 60) ||
        (current.level == "levels\\halo1\\solo\\b30\\b30" && current.cutscene == 0 && current.bsp == 1) ||
        (current.level == "levels\\halo1\\solo\\b40\\b40" && current.cutscene == 0 && current.bsp == 4) ||
        (current.level == "levels\\halo1\\solo\\c10\\c10" && current.cutscene == 0 && current.bsp == 3) ||
        (current.level == "levels\\halo1\\solo\\c20\\c20" && current.cutscene == 0 && current.bsp == 8) ||
        (current.level == "levels\\halo1\\solo\\c45\\c45" && current.cutscene == 0 && current.bsp == 3) ||
        (current.level == "levels\\halo1\\solo\\d20\\d20" && current.cutscene == 0 && current.bsp == 4 && (current.x < 55 && current.x != 0))
    ) {
        if (settings["il_mode"]) {
            vars.end = true;
        }   
        vars.forceIsLoading = true;
    }
}

start {
    vars.end = false;
    vars.forceIsLoading = false;

    vars.dirtybsps.Clear();
    vars.dirtybsps.Add(0);

    return current.loadState == 4       // wait until in game
        && current.tick != old.tick     // wait until out of cutscene
        && current.tick > 3             // wait until out of cutscene
        && current.cutscene == 1        // wait until out of cutscene
        && current.tick < 30            // only start in first half second
        ;
}

reset {
    if (settings["il_mode"]) {
        return current.tick < 3;
    }
    return (current.level == "levels\\halo1\\solo\\a15\\a15" || current.level == "levels\\halo1\\solo\\e10\\e10") && current.tick < 3;
}

split {
    // setting a split flag for ILs in update, because we also need the end conditions in update to ensure we can force loading
    // to prevent the timer from running during cutscenes briefly after a level end

    if (vars.end) {
        return true;
    }

    if (current.level == "levels\\halo1\\solo\\d40\\d40" && current.cutscene == 0 && current.bsp == 3) {
        return true; // always split at end of Maw
    }

    if (settings["cutscene_split"] && current.cutscene == 0 && current.cutscene != old.cutscene && current.tick > 60) {
        return true;
    }

    if (settings["bsp_split"] && current.bsp != old.bsp && vars.dirtybsps.Contains(current.bsp) == false) {
        vars.dirtybsps.Add(current.bsp);
        return true;
    }

    if (current.level != old.level) {
        vars.forceIsLoading = false;
        return true;
    }
}

isLoading {
    return vars.forceIsLoading || current.loadState != 4 || current.cutscene == 0 || current.paused == 1 || current.tick <= 3;
}