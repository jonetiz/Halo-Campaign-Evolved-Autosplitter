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
}

state("HaloCampaignEvolved", "2026.06.26.1097863.1-Rel-i343-Meteorite-2606-CU2") {
    int         loadState   : "HaloSimulation_tag_release.dll", 0xCA3844;
    string32    level       : "HaloSimulation_tag_release.dll", 0xCA3F20;
    int         tick        : "HaloSimulation_tag_release.dll", 0x12954A8, 0x0;
    byte        cutscene    : "HaloSimulation_tag_release.dll", 0xA2C3C1;           // 0 = cutscene, 1 = gameplay; aligned to 0xA2C3C0
    byte        paused      : 0xD3ACED8, 0x618;                                     // 0 = unpaused, 1 = paused
    int         bsp         : "HaloSimulation_tag_release.dll", 0x9A24D8;
}

startup {
    vars.end = false;
    vars.forceIsLoading = false;

    vars.position = new float[3];
    vars.oldPosition = new float[3];

    vars.mainThreadId = 0;
    vars.teb = IntPtr.Zero;
    vars.moduleBase = IntPtr.Zero;
    
    vars.tls_index_offset = 0xD72730;

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
    version = modules.First().FileVersionInfo.ProductVersion;

    switch (version) {
        case "2026.07.25.1112544.4-Rel-i343-Meteorite-2607-CU3":
            vars.tls_index_offset = 0xD72730;
            break;
            
        case "2026.06.26.1097863.1-Rel-i343-Meteorite-2606-CU2":
            vars.tls_index_offset = 0xD73730;
            break;
    }

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
                    (int)vars.tls_index_offset
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

    if (
        (current.level == "levels\\halo1\\solo\\a15\\a15" && current.cutscene == 0 && current.bsp == 3) ||
        (current.level == "levels\\halo1\\solo\\a30\\a30" && current.cutscene == 0 && current.bsp == 2) ||
        (current.level == "levels\\halo1\\solo\\a30\\a30" && current.cutscene == 0 && current.bsp == 2) ||
        (current.level == "levels\\halo1\\solo\\a50\\a50" && current.cutscene == 0 && current.bsp == 5 && vars.position[0] > 60) ||
        (current.level == "levels\\halo1\\solo\\b30\\b30" && current.cutscene == 0 && current.bsp == 1) ||
        (current.level == "levels\\halo1\\solo\\b40\\b40" && current.cutscene == 0 && current.bsp == 4) ||
        (current.level == "levels\\halo1\\solo\\c10\\c10" && current.cutscene == 0 && current.bsp == 3) ||
        (current.level == "levels\\halo1\\solo\\c20\\c20" && current.cutscene == 0 && current.bsp == 8) ||
        (current.level == "levels\\halo1\\solo\\c45\\c45" && current.cutscene == 0 && current.bsp == 3) ||
        (current.level == "levels\\halo1\\solo\\d20\\d20" && current.cutscene == 0 && current.bsp == 4 && vars.position[0] < 60)
    ) {
        if (settings["il_mode"]) {
            vars.end = true;
        }   
        vars.forceIsLoading = true;
    }

    return true;
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