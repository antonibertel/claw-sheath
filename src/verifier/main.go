package main

import (
	"context"
	"flag"
	"fmt"
	"os"
	"strings"

	"github.com/teilomillet/gollm"
	"gopkg.in/yaml.v3"
)

type Config struct {
	LLM struct {
		Enabled  bool   `yaml:"enabled"`
		Provider string `yaml:"provider"`
		Model    string `yaml:"model"`
		Token    string `yaml:"token"`
	} `yaml:"llm"`
}

func main() {
	cmdFlag := flag.String("cmd", "", "The full restricted command being executed")
	justifyFlag := flag.String("justify", "", "The user-provided justification for the command")
	configFlag := flag.String("config", "", "Path to config.yml")

	flag.Parse()

	if *cmdFlag == "" || *justifyFlag == "" || *configFlag == "" {
		fmt.Fprintln(os.Stderr, "Usage: sheath-verifier --config <file.yml> --cmd <command> --justify <justification>")
		os.Exit(2)
	}

	justification := *justifyFlag
	cmdStr := *cmdFlag

	// Manual override bypass
	if strings.HasPrefix(strings.TrimSpace(justification), "!override!") {
		fmt.Println("ALLOWED by override pattern detected.")
		os.Exit(0)
	}

	yamlFile, err := os.ReadFile(*configFlag)
	if err != nil {
		fmt.Fprintln(os.Stderr, "Error reading config file:", err)
		os.Exit(0) // Fail open
	}

	var conf Config
	if err := yaml.Unmarshal(yamlFile, &conf); err != nil {
		fmt.Fprintln(os.Stderr, "Error parsing yaml:", err)
		os.Exit(0)
	}

	if !conf.LLM.Enabled {
		fmt.Println("ALLOWED by configuration (LLM judge disabled).")
		os.Exit(0)
	}

	if conf.LLM.Token == "" || conf.LLM.Provider == "" {
		fmt.Fprintln(os.Stderr, "Error: Missing LLM token or provider in config.")
		os.Exit(0)
	}

	// Create gollm instances
	llm, err := gollm.NewLLM(
		gollm.SetProvider(conf.LLM.Provider),
		gollm.SetModel(conf.LLM.Model),
		gollm.SetAPIKey(conf.LLM.Token),
		gollm.SetMaxTokens(150),
		gollm.SetTemperature(0.1),
		gollm.SetCustomValidator(func(v interface{}) error { return nil }),
	)

	if err != nil {
		fmt.Fprintf(os.Stderr, "Failed to initialize LLM provider: %v\n", err)
		os.Exit(0)
	}

	systemPrompt := `You are a strict security guard evaluating if a bash command should be allowed based on the user's justification.
If the justification is solid, clear, and makes sense for the command, ALLOW it.
If the command seems extremely destructive without good reason, or the justification is vague, weak, or nonsensical (like "doing stuff", "test", "because"), DENY it.

Your response MUST start with either exactly "ALLOW" or exactly "DENY" on the first line.
The second line should be a brief explanation of your decision (if DENY, state your concerns and propose to the user that they can bypass this by prepending "!override!" to their justification if they are absolutely sure).`

	userPrompt := fmt.Sprintf("Command to execute: `%s`\nUser's proposed justification: \"%s\"\n\nDecision:", cmdStr, justification)
	prompt := gollm.NewPrompt(userPrompt, gollm.WithSystemPrompt(systemPrompt, gollm.CacheTypeEphemeral))

	ctx := context.Background()
	responseTxt, err := llm.Generate(ctx, prompt)
	if err != nil {
		fmt.Fprintf(os.Stderr, "LLM Generation failed: %v\n", err)
		os.Exit(0)
	}

	if responseTxt == "" {
		fmt.Fprintln(os.Stderr, "Empty response from LLM.")
		os.Exit(0)
	}

	responseTxt = strings.TrimSpace(responseTxt)
	lines := strings.SplitN(responseTxt, "\n", 2)
	decision := strings.TrimSpace(lines[0])

	reasoning := ""
	if len(lines) > 1 {
		reasoning = strings.TrimSpace(lines[1])
	}

	if strings.HasPrefix(strings.ToUpper(decision), "DENY") {
		fmt.Printf("REJECTED by LLM Guard: %s\n", reasoning)
		os.Exit(1)
	}

	fmt.Printf("ALLOWED by LLM Guard: %s\n", reasoning)
	os.Exit(0)
}
