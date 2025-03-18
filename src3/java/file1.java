import java.io.*;

public class SubdomainEnumeration {
    public static void main(String[] args) {
        if (args.length != 1) {
            System.out.println("Usage: java SubdomainEnumeration <domain>");
            return;
        }

        String domain = args[0];
        String scriptPath = "./subdomain_enum.sh"; // Path to the Bash script
        
        try {
            ProcessBuilder builder = new ProcessBuilder("bash", scriptPath, domain);
            builder.redirectErrorStream(true);
            Process process = builder.start();

            BufferedReader reader = new BufferedReader(new InputStreamReader(process.getInputStream()));
            String line;
            while ((line = reader.readLine()) != null) {
                System.out.println(line);
            }

            int exitCode = process.waitFor();
            System.out.println("Script exited with code: " + exitCode);
        } catch (IOException | InterruptedException e) {
            e.printStackTrace();
        }
    }
}
