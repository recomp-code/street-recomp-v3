// Prints the disassembly of address ranges given as script arguments: start end [start end ...]
// @category PS2Recomp
import ghidra.app.script.GhidraScript;
import ghidra.app.cmd.disassemble.DisassembleCommand;
import ghidra.program.model.address.Address;
import ghidra.program.model.address.AddressSet;
import ghidra.program.model.listing.Instruction;

public class DumpRanges extends GhidraScript {
    @Override
    public void run() throws Exception {
        String[] args = getScriptArgs();
        for (int i = 0; i + 1 < args.length; i += 2) {
            Address start = toAddr(Long.decode(args[i]));
            Address end = toAddr(Long.decode(args[i + 1]));
            DisassembleCommand cmd = new DisassembleCommand(new AddressSet(start, end), null, true);
            cmd.applyTo(currentProgram, monitor);
            println("==== " + start + " - " + end);
            Address a = start;
            while (a.compareTo(end) <= 0) {
                Instruction ins = getInstructionAt(a);
                if (ins == null) {
                    println(a + ": .word 0x" + Integer.toHexString(getInt(a)));
                    a = a.add(4);
                } else {
                    println(a + ": " + ins.toString());
                    a = a.add(ins.getLength());
                }
            }
        }
    }
}
