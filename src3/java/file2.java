import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStreamReader;

public class SubdomainEnumerator {
    public static void main(String[] args) {
        if (args.length != 1) {
            System.out.println("Usage: java SubdomainEnumerator <domain>");
            return;
        }

        String domain = args[0];
        String bashScript = "./subdomain_enum.sh"; // Ensure the script is executable

        try {
            ProcessBuilder processBuilder = new ProcessBuilder("bash", bashScript, domain);
            processBuilder.redirectErrorStream(true);
            Process process = processBuilder.start();

            BufferedReader reader = new BufferedReader(new InputStreamReader(process.getInputStream()));
            String line;
            while ((line = reader.readLine()) != null) {
                System.out.println(line);
            }

            int exitCode = process.waitFor();
            System.out.println("Process exited with code: " + exitCode);
        } catch (IOException | InterruptedException e) {
            e.printStackTrace();
        }
    }
}
