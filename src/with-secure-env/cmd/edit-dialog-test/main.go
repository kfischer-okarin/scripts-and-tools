package main

import (
	"encoding/json"
	"fmt"
	"os"

	"github.com/kfischer-okarin/with-secure-env/internal/editdialog"
)

func main() {
	if len(os.Args) < 2 {
		fmt.Fprintln(os.Stderr, "Usage: edit-dialog-test '{\"KEY\": \"value\"}'")
		os.Exit(1)
	}

	var input map[string]string
	if err := json.Unmarshal([]byte(os.Args[1]), &input); err != nil {
		fmt.Fprintf(os.Stderr, "Invalid JSON: %v\n", err)
		os.Exit(1)
	}

	dialog := &editdialog.WebViewEditDialog{}
	result, ok := dialog.EditEnvs("/test/app/path", input)

	if !ok {
		fmt.Fprintln(os.Stderr, "Canceled")
		os.Exit(1)
	}

	output, _ := json.MarshalIndent(result, "", "  ")
	fmt.Println(string(output))
}
