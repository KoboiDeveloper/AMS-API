package controllers

import (
	"net/http"
)

func HelloWorld(w http.ResponseWriter, r *http.Request) {
	banner := `
  ___   _  __ _   _ 
 / _ \ | |/ /| | | |
/ /_\ \| ' / | | | |
|  _  || . \ | |_| |
|_| |_||_|\_\ \___/ 

 ____    _  __   _   _   _   ____ 
/ ___|  / \ \ \ / / / \ | \ | / ___|
\___ \ / _ \ \ V / / _ \|  \| | |  _
 ___) / ___ \ | | / ___ \ |\  | |_| |
|____/_/   \_\|_|/_/   \_\_| \_|\____|

 _  __     _    __  __  _   _
| |/ /    / \  |  \/  || | | |
| ' /    / _ \ | |\/| || | | |
| . \   / ___ \| |  | || |_| |
|_|\_\ /_/   \_\_|  |_(_)___/
`

	w.Header().Set("Content-Type", "text/plain; charset=utf-8")
	w.WriteHeader(http.StatusOK)
	_, _ = w.Write([]byte(banner))
}

// test
