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
    byte        cutscene    : "HaloSimulation_tag_release.dll", 0xA2C3C1;           // 0 = cutscene, 1 = gameplay; aligned to 0xA2C3C0
    int         bsp         : "HaloSimulation_tag_release.dll", 0x9A24D8;
}

startup {
    vars.position = new float[3];
    vars.oldPosition = new float[3];

    vars.mainThreadId = 0;
    vars.teb = IntPtr.Zero;
    vars.moduleBase = IntPtr.Zero;

    /*
        Build a tiny helper class at runtime so ASL can call:

            OpenThread
            NtQueryInformationThread
            CloseHandle

        ThreadBasicInformation (class 0) gives us the TEB address.
    */

    var code = @"
    using System;
    using System.Runtime.InteropServices;

    public static class HaloThreadHelper
    {
        [StructLayout(LayoutKind.Sequential)]
        public struct CLIENT_ID
        {
            public IntPtr UniqueProcess;
            public IntPtr UniqueThread;
        }

        [StructLayout(LayoutKind.Sequential)]
        public struct THREAD_BASIC_INFORMATION
        {
            public int ExitStatus;
            public IntPtr TebBaseAddress;
            public CLIENT_ID ClientId;
            public UIntPtr AffinityMask;
            public int Priority;
            public int BasePriority;
        }

        [DllImport(""kernel32.dll"", SetLastError = true)]
        static extern IntPtr OpenThread(
            uint dwDesiredAccess,
            bool bInheritHandle,
            uint dwThreadId
        );

        [DllImport(""kernel32.dll"")]
        static extern bool CloseHandle(IntPtr hObject);

        [DllImport(""ntdll.dll"")]
        static extern int NtQueryInformationThread(
            IntPtr ThreadHandle,
            int ThreadInformationClass,
            IntPtr ThreadInformation,
            int ThreadInformationLength,
            IntPtr ReturnLength
        );

        const uint THREAD_QUERY_INFORMATION = 0x0040;

        public static IntPtr GetStartAddress(uint threadId)
        {
            IntPtr handle =
                OpenThread(THREAD_QUERY_INFORMATION, false, threadId);

            if (handle == IntPtr.Zero)
                return IntPtr.Zero;

            IntPtr buffer = Marshal.AllocHGlobal(IntPtr.Size);

            try
            {
                Marshal.WriteIntPtr(buffer, IntPtr.Zero);

                // ThreadQuerySetWin32StartAddress = 9
                int status = NtQueryInformationThread(
                    handle,
                    9,
                    buffer,
                    IntPtr.Size,
                    IntPtr.Zero
                );

                if (status != 0)
                    return IntPtr.Zero;

                return Marshal.ReadIntPtr(buffer);
            }
            finally
            {
                Marshal.FreeHGlobal(buffer);
                CloseHandle(handle);
            }
        }

        public static IntPtr GetTeb(uint threadId)
        {
            IntPtr handle =
                OpenThread(THREAD_QUERY_INFORMATION, false, threadId);

            if (handle == IntPtr.Zero)
                return IntPtr.Zero;

            int size = Marshal.SizeOf(typeof(THREAD_BASIC_INFORMATION));
            IntPtr buffer = Marshal.AllocHGlobal(size);

            try
            {
                int status = NtQueryInformationThread(
                    handle,
                    0, // ThreadBasicInformation
                    buffer,
                    size,
                    IntPtr.Zero
                );

                if (status != 0)
                    return IntPtr.Zero;

                var info =
                    (THREAD_BASIC_INFORMATION)Marshal.PtrToStructure(
                        buffer,
                        typeof(THREAD_BASIC_INFORMATION)
                    );

                return info.TebBaseAddress;
            }
            finally
            {
                Marshal.FreeHGlobal(buffer);
                CloseHandle(handle);
            }
        }
    }
    ";

    var provider =
        new Microsoft.CSharp.CSharpCodeProvider();

    var parameters =
        new System.CodeDom.Compiler.CompilerParameters();

    parameters.GenerateInMemory = true;
    parameters.ReferencedAssemblies.Add("System.dll");

    var result =
        provider.CompileAssemblyFromSource(parameters, code);

    if (result.Errors.HasErrors)
    {
        foreach (System.CodeDom.Compiler.CompilerError error in result.Errors)
            print(error.ToString());

        throw new Exception("Failed to compile HaloThreadHelper");
    }

    vars.threadHelper =
        result.CompiledAssembly.GetType("HaloThreadHelper");

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

init {
    vars.mainThreadId = 0;
    vars.teb = IntPtr.Zero;

    var module = modules
        .Where(m =>
            String.Equals(
                m.ModuleName,
                "HaloSimulation_tag_release.dll",
                StringComparison.OrdinalIgnoreCase
            )
        )
        .FirstOrDefault();

    if (module == null)
    {
        print("ERROR: HaloSimulation_tag_release.dll not found");
        return false;
    }

    vars.moduleBase = module.BaseAddress;

    long moduleBase =
        module.BaseAddress.ToInt64();

    long wantedStart =
        moduleBase + 0x9E60;

    print(
        "Module base: 0x" +
        moduleBase.ToString("X")
    );

    print(
        "Looking for thread start: 0x" +
        wantedStart.ToString("X")
    );

    var getStart =
        vars.threadHelper.GetMethod("GetStartAddress");

    var getTeb =
        vars.threadHelper.GetMethod("GetTeb");

    foreach (System.Diagnostics.ProcessThread thread in game.Threads)
    {
        try
        {
            IntPtr start =
                (IntPtr)getStart.Invoke(
                    null,
                    new object[] { (uint)thread.Id }
                );

            print(
                "TID " + thread.Id +
                " native start=0x" +
                start.ToInt64().ToString("X")
            );

            if (start.ToInt64() != wantedStart)
                continue;

            print(
                "FOUND game_MAIN_THREAD: TID " +
                thread.Id
            );

            vars.mainThreadId = thread.Id;

            vars.teb =
                (IntPtr)getTeb.Invoke(
                    null,
                    new object[] { (uint)thread.Id }
                );

            print(
                "TEB = 0x" +
                ((IntPtr)vars.teb)
                .ToInt64()
                .ToString("X")
            );

            break;
        }
        catch (Exception ex)
        {
            print(
                "TID " + thread.Id +
                " query failed: " +
                ex.Message
            );
        }
    }

    if (vars.mainThreadId == 0)
    {
        print(
            "ERROR: couldn't find thread with start module+9E60"
        );
        return false;
    }

    if ((IntPtr)vars.teb == IntPtr.Zero)
    {
        print(
            "ERROR: found main thread but TEB lookup failed"
        );
        return false;
    }

    return true;
}

update {
    if ((IntPtr)vars.teb == IntPtr.Zero)
        return false;

    try
    {
        // Preserve previous XYZ.
        for (int i = 0; i < 3; i++)
            vars.oldPosition[i] = vars.position[i];


        // --------------------------------------------------
        // TEB + 0x58 -> ThreadLocalStoragePointer
        // --------------------------------------------------

        IntPtr tlsArray =
            game.ReadPointer(
                IntPtr.Add((IntPtr)vars.teb, 0x58)
            );

        if (tlsArray == IntPtr.Zero)
            return false;


        // --------------------------------------------------
        // TLS index:
        // HaloSimulation_tag_release.dll+D73730
        // --------------------------------------------------

        int tlsIndex =
            game.ReadValue<int>(
                IntPtr.Add(
                    (IntPtr)vars.moduleBase,
                    0xD73730
                )
            );

        if (tlsIndex < 0)
            return false;


        // --------------------------------------------------
        // TLS[index]
        //
        // x64 pointer size = 8 bytes
        // --------------------------------------------------

        IntPtr tlsContext =
            game.ReadPointer(
                IntPtr.Add(
                    tlsArray,
                    tlsIndex * 8
                )
            );

        if (tlsContext == IntPtr.Zero)
            return false;


        // --------------------------------------------------
        // [tlsContext + 0x458]
        // --------------------------------------------------

        IntPtr positionBase =
            game.ReadPointer(
                IntPtr.Add(tlsContext, 0x458)
            );

        if (positionBase == IntPtr.Zero)
            return false;


        // --------------------------------------------------
        // XYZ
        //
        // X = +51F8
        // Y = +51FC
        // Z = +5200
        // --------------------------------------------------

        for (int i = 0; i < 3; i++)
        {
            vars.position[i] =
                game.ReadValue<float>(
                    IntPtr.Add(
                        positionBase,
                        0x51F8 + i * 4
                    )
                );
        }
    }
    catch
    {
        // Don't kill the autosplitter if the object disappears
        // briefly during loads / level transitions.
        return false;
    }

    return true;
}

start {
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
    print(
        vars.position[0] + ", " +
        vars.position[1] + ", " +
        vars.position[2]
    );

    if (settings["il_mode"]) {
        if (current.level == "levels\\halo1\\solo\\a15\\a15" && current.cutscene == 0 && current.bsp == 3) {
            return true;
        }
        if (current.level == "levels\\halo1\\solo\\a30\\a30" && current.cutscene == 0 && current.bsp == 2) {
            return true;
        }
        if (current.level == "levels\\halo1\\solo\\a50\\a50" && current.cutscene == 0 && current.bsp == 5 && vars.position[0] > 60) {
            return true;
        }
        if (current.level == "levels\\halo1\\solo\\b30\\b30" && current.cutscene == 0 && current.bsp == 1) {
            return true;
        }
        if (current.level == "levels\\halo1\\solo\\b40\\b40" && current.cutscene == 0 && current.bsp == 4) {
            return true;
        }
        if (current.level == "levels\\halo1\\solo\\c10\\c10" && current.cutscene == 0 && current.bsp == 3) {
            return true;
        }
        if (current.level == "levels\\halo1\\solo\\c20\\c20" && current.cutscene == 0 && current.bsp == 8) {
            return true;
        }
        if (current.level == "levels\\halo1\\solo\\c45\\c45" && current.cutscene == 0 && current.bsp == 3) {
            return true;
        }
        if (current.level == "levels\\halo1\\solo\\d20\\d20" && current.cutscene == 0 && current.bsp == 4 && vars.position[0] < 60) {
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
    if (current.level == "levels\\halo1\\solo\\d40\\d40" && current.cutscene == 0 && current.bsp == 3) {
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