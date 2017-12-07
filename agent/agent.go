// Copyright © 2017 Ricardo Aravena <raravena@branch.io>
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

// Package agent Main package for ssh agent
package agent

import (
	"fmt"
	"golang.org/x/crypto/ssh/agent"
	"io"
	"net"
	"os"
	"os/signal"
)

// SetupSSHAgent Function that setups ssh agent
func SetupSSHAgent(socketFile string) {
	a := agent.NewKeyring()
	fmt.Println("Starting SSH Agent on:", socketFile)
	ln, err := net.Listen("unix", socketFile)
	if err != nil {
		panic(fmt.Sprintf("Couldn't create socket for tests %v", err))
	}

	for {
		c, err := ln.Accept()
		defer c.Close()
		if err != nil {
			panic(fmt.Sprintf("Couldn't accept connection to agent tests %v", err))
		}
		go func(c io.ReadWriter) {
			err := agent.ServeAgent(a, c)
			if err != nil {
				fmt.Sprintf("Couldn't serve ssh agent for tests %v", err)
			}

		}(c)
	}
}

// RunAgent Main function that runs the ssh agent
func RunAgent(socketFile string) {
	// Clean up on Exit
	c := make(chan os.Signal, 1)
	signal.Notify(c, os.Interrupt)
	go func() {
		for sig := range c {
			fmt.Println("Cleaning up", sig)
			os.Remove(socketFile)
			os.Exit(0)
		}
	}()
	SetupSSHAgent(socketFile)
}
