package danga.s2;

import java.io.InputStream;
import java.io.FileInputStream;
import java.io.File;
import java.util.Hashtable;

class s2compile
{
    public static void main (String[] args) throws Exception
    {
	if (args.length < 3 || args.length % 2 != 1) { usage(); return; }
        Hashtable hargs = new Hashtable();
        int i = 0;
        while (args[i].startsWith("-") && i != args.length-1) {
            String key = args[i].substring(1, args[i].length());
            String val = args[i+1];
            i += 2;
            hargs.put(key, val);
        }
        if (i != args.length - 1) { usage(); return; }
        String filename = args[i];

        String format = (String) hargs.get("output");
        if (format == null) {
            System.err.println("No output format specified");
            return;
        }

        // Tokens output format requires no validation.
        if (format.equals("tokens")) {
            Tokenizer toker = new Tokenizer(getInputStream(filename));
	    try {
		Token tok;
		while ((tok = toker.getToken()) != null) {
		    System.out.println(tok.toString());
		}
	    } catch (Exception e) {
		System.err.println(e.toString());
		return;
	    }
	    System.out.println("end.");
	    return;
        }

        String layertype = (String) hargs.get("layertype");
        if (layertype == null) {
            System.err.println("Unspecified layertype.");
            return;
        }

	Checker ck = null;
        Layer layerMain;

        // TODO: respect cmdline option to pre-load serialized checker to
        //       avoid having to make one by reparsing source of core[+layout]

        if (layertype.equals("core")) {
            ck = new Checker();
        }
        else if (layertype.equals("i18nc") || layertype.equals("layout")) {
            if (ck == null) {
                ck = new Checker();
                makeLayer((String) hargs.get("core"), "core", ck);
            }
        }
        else if (layertype.equals("theme") || layertype.equals("i18n") ||
                 layertype.equals("user")) {
            if (ck == null) {
                ck = new Checker();
                makeLayer((String) hargs.get("core"), "core", ck);
                makeLayer((String) hargs.get("layout"), "layout", ck);
            }
        }
        else {
            System.err.println("Invalid layertype.");
            return;
        }
        layerMain = makeLayer(filename, layertype, ck);

	Output o = new OutputConsole();
	Backend be = null;

	if (format.equals("html"))
	    be = new BackendHTML(layerMain);

	if (format.equals("s2"))
	    be = new BackendS2(layerMain);

	if (format.equals("perl")) {
            int layerid = 0;
            try {
                layerid = Integer.parseInt((String) hargs.get("layerid"));
            } catch (Exception e) {
                System.err.println("Unspecified -layerid <n>");
                return;
            }
	    be = new BackendPerl(layerMain, layerid);
	}

	if (be == null) {
	    System.err.println("No backend found for '" + format + "'");
	    return;
	}

	be.output(o);
	return;
    }

    private static int usage () {
	System.err.println("Usage: ");
	System.err.println("   s2compile [opts]* <file>\n");
        System.err.println("Options:");
        System.err.println("   -output <format>     One of: perl, html, s2, tokens");
        System.err.println("   -layerid <int>       For perl output format only");
        System.err.println("   -layertype <type>    One of: core, i18nc, layer, theme, i18n, user");
        System.err.println("   -core <filename>     Core S2 file, if layertype after core");
        System.err.println("   -layout <filename>   Layout S2 file, if compiling layer after layout");
	System.err.println("\nAny file args can be '-' to read from STDIN, ending with ^D");
	return 1;
    }

    public static InputStream getInputStream (String filename) throws Exception {
        if (filename.equals("-"))
            return System.in;
        return new FileInputStream(new File(filename));
    }

    public static Layer makeLayer (String filename, String type, Checker ck) throws Exception
    {
        if (filename == null) {
            throw new Exception("Undefined filename for "+type+" layer.");
        }
	Tokenizer toker = new Tokenizer(getInputStream(filename));
	Layer s2l = new Layer(toker, type);
	// now check the layer, since it must have parsed fine (otherwise
	// the Layer constructor would have thrown an exception
	ck.checkLayer(s2l);
	return s2l;
    }
}
