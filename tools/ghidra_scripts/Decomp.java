// Decompiles functions / lists references, for reverse engineering from the headless analyzer.
// Args: an output file followed by commands: "d:<addr>" decompile the function containing addr,
// "x:<addr>" list references to addr (code and data), "s:<text>" find string addresses + refs.
// @category PS2Recomp
import ghidra.app.script.GhidraScript;
import ghidra.app.decompiler.DecompInterface;
import ghidra.app.decompiler.DecompileResults;
import ghidra.program.model.address.Address;
import ghidra.program.model.listing.Function;
import ghidra.program.model.symbol.Reference;
import ghidra.program.model.mem.Memory;
import java.io.PrintWriter;
import java.io.FileWriter;

public class Decomp extends GhidraScript {
    @Override
    public void run() throws Exception {
        String[] args = getScriptArgs();
        PrintWriter out = new PrintWriter(new FileWriter(args[0]));
        DecompInterface dec = new DecompInterface();
        dec.openProgram(currentProgram);
        for (int i = 1; i < args.length; ++i) {
            String a = args[i];
            if (a.startsWith("d:")) {
                Address addr = toAddr(Long.decode(a.substring(2)));
                Function f = getFunctionContaining(addr);
                if (f == null) {
                    disassemble(addr);
                    f = createFunction(addr, null);
                }
                if (f == null) { out.println("// no function at " + addr); continue; }
                DecompileResults r = dec.decompileFunction(f, 120, monitor);
                out.println("// ===== " + f.getName() + " @ " + f.getEntryPoint());
                if (r != null && r.getDecompiledFunction() != null)
                    out.println(r.getDecompiledFunction().getC());
                else
                    out.println("// decompile failed: " + (r == null ? "null" : r.getErrorMessage()));
            } else if (a.startsWith("x:")) {
                Address addr = toAddr(Long.decode(a.substring(2)));
                out.println("// ===== refs to " + addr);
                for (Reference ref : getReferencesTo(addr)) {
                    Function f = getFunctionContaining(ref.getFromAddress());
                    out.println("  " + ref.getFromAddress() + " " + ref.getReferenceType() + " in " + (f == null ? "?" : f.getName() + "@" + f.getEntryPoint()));
                }
            } else if (a.startsWith("m:")) {
                String[] p = a.substring(2).split("/");
                Address addr = toAddr(Long.decode(p[0]));
                int len = Integer.decode(p[1]);
                byte[] buf = getBytes(addr, len);
                StringBuilder sb = new StringBuilder();
                for (byte b : buf) sb.append(b >= 32 && b < 127 ? (char) b : (b == 0 ? '|' : '.'));
                out.println("// ===== mem " + addr + ": " + sb);
            } else if (a.startsWith("a:")) {
                String[] p = a.substring(2).split("/");
                Address addr = toAddr(Long.decode(p[0]));
                Address end = toAddr(Long.decode(p[1]));
                out.println("// ===== disasm " + addr + " - " + end);
                while (addr.compareTo(end) <= 0) {
                    ghidra.program.model.listing.Instruction ins = getInstructionAt(addr);
                    if (ins == null) {
                        out.println(addr + ": .word " + String.format("%08x", getInt(addr)));
                        addr = addr.add(4);
                    } else {
                        out.println(addr + ": " + ins.toString());
                        addr = addr.add(ins.getLength());
                    }
                }
            } else if (a.startsWith("w:")) {
                String[] p = a.substring(2).split("/");
                Address addr = toAddr(Long.decode(p[0]));
                int count = Integer.decode(p[1]);
                StringBuilder sb = new StringBuilder();
                for (int k = 0; k < count; ++k)
                    sb.append(String.format(" %08x", getInt(addr.add(4L * k))));
                out.println("// ===== words " + addr + ":" + sb);
            } else if (a.startsWith("s:")) {
                String text = a.substring(2);
                Memory mem = currentProgram.getMemory();
                Address found = mem.findBytes(currentProgram.getMinAddress(), text.getBytes(), null, true, monitor);
                while (found != null) {
                    out.println("// ===== string '" + text + "' at " + found);
                    for (Reference ref : getReferencesTo(found)) {
                        Function f = getFunctionContaining(ref.getFromAddress());
                        out.println("  " + ref.getFromAddress() + " in " + (f == null ? "?" : f.getName() + "@" + f.getEntryPoint()));
                    }
                    found = mem.findBytes(found.add(1), text.getBytes(), null, true, monitor);
                }
            }
        }
        out.close();
    }
}
