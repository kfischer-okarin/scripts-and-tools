package main

import (
	"fmt"

	"github.com/kfischer-okarin/with-secure-env/internal/permissiondialog"
)

func main() {
	dialog := &permissiondialog.WebViewPermissionDialog{}

	allowed := dialog.AskPermission(
		"/usr/local/bin/my-secure-app",
		[]string{"--config", "/etc/myapp.conf", "--verbose"},
		[]string{"DATABASE_URL", "API_KEY", "SECRET_TOKEN"},
		permissiondialog.CallerInfo{
			Name: "terminal",
			PID:  12345,
		},
	)

	if allowed {
		fmt.Println("Permission granted")
	} else {
		fmt.Println("Permission denied")
	}
}
