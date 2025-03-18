import java.io.*;
import java.util.Scanner;

public class BashIntegrationInJava {

    public static void runBashCommand(String command) {
        try {
            System.out.println("\nExecuting Command: " + command);
            
            String[] bashCommand = {"/bin/bash", "-c", command};
            ProcessBuilder processBuilder = new ProcessBuilder(bashCommand);
            Process process = processBuilder.start();

            readProcessOutput(process, "command_output.log");

            int exitCode = process.waitFor();
            System.out.println("Command exited with code: " + exitCode);

        } catch (IOException | InterruptedException e) {
            e.printStackTrace();
        }
    }

    public static void runBashScript(String scriptPath) {
        try {
            File scriptFile = new File(scriptPath);
            if (!scriptFile.exists()) {
                System.out.println("Error: Script file not found!");
                return;
            }

            System.out.println("\nExecuting Script: " + scriptPath);

            String[] bashCommand = {"/bin/bash", scriptPath};
            ProcessBuilder processBuilder = new ProcessBuilder(bashCommand);
            Process process = processBuilder.start();

            readProcessOutput(process, "script_output.log");

            int exitCode = process.waitFor();
            System.out.println("Script exited with code: " + exitCode);

        } catch (IOException | InterruptedException e) {
            e.printStackTrace();
        }
    }

    private static void readProcessOutput(Process process, String logFileName) {
        try (BufferedWriter logWriter = new BufferedWriter(new FileWriter(logFileName, true))) {
            
            Thread outputThread = new Thread(() -> {
                try (BufferedReader reader = new BufferedReader(new InputStreamReader(process.getInputStream()))) {
                    String line;
                    while ((line = reader.readLine()) != null) {
                        System.out.println("[OUTPUT] " + line);
                        logWriter.write(line + "\n");
                    }
                } catch (IOException e) {
                    e.printStackTrace();
                }
            });

            Thread errorThread = new Thread(() -> {
                try (BufferedReader reader = new BufferedReader(new InputStreamReader(process.getErrorStream()))) {
                    String line;
                    while ((line = reader.readLine()) != null) {
                        System.err.println("[ERROR] " + line);
                        logWriter.write("ERROR: " + line + "\n");
                    }
                } catch (IOException e) {
                    e.printStackTrace();
                }
            });

            outputThread.start();
            errorThread.start();
            outputThread.join();
            errorThread.join();

        } catch (IOException | InterruptedException e) {
            e.printStackTrace();
        }
    }

    private static void interactiveMenu() {
        Scanner scanner = new Scanner(System.in);
        while (true) {
            System.out.println("\n=== Bash Integration Menu ===");
            System.out.println("1. Execute a Bash Command");
            System.out.println("2. Run a Bash Script");
            System.out.println("3. Exit");
            System.out.print("Choose an option: ");
            int choice = scanner.nextInt();
            scanner.nextLine(); 

            switch (choice) {
                case 1:
                    System.out.print("Enter the Bash command: ");
                    String command = scanner.nextLine();
                    runBashCommand(command);
                    break;

                case 2:
                    System.out.print("Enter the Bash script path: ");
                    String scriptPath = scanner.nextLine();
                    runBashScript(scriptPath);
                    break;

                case 3:
                    System.out.println("Exiting program...");
                    scanner.close();
                    return;

                default:
                    System.out.println("Invalid option! Try again.");
            }
        }
    }

    public static void main(String[] args) {
        System.out.println("=== Bash Integration in Java ===");

        runBashCommand("echo 'Hello from Bash!'");
        runBashCommand("ls -l");
        runBashCommand("df -h | grep '/$'");

        String scriptPath = "test_script.sh";  
        runBashScript(scriptPath);

        interactiveMenu();

        System.out.println("\n=== Program Ended ===");
    }
}
