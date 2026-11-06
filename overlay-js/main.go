package main

import (
	"errors"
	"fmt"
	"io"
	"os"
	"reflect"
	"strings"

	"github.com/dop251/goja"
)

func main() {
	if len(os.Args) != 2 {
		fmt.Fprintln(os.Stderr, "usage: mihomo-overlay-js overlay.js < config.json")
		os.Exit(1)
	}
	if err := run(os.Args[1]); err != nil {
		fmt.Fprintln(os.Stderr, "overlay.js:", err)
		os.Exit(1)
	}
}

func run(path string) error {
	source, err := os.ReadFile(path)
	if err != nil {
		return err
	}
	input, err := io.ReadAll(os.Stdin)
	if err != nil {
		return err
	}

	vm := goja.New()
	// Keep the original JSON functions in case the overlay changes them.
	jsonObject := vm.Get("JSON").ToObject(vm)
	parse, _ := goja.AssertFunction(jsonObject.Get("parse"))
	stringify, _ := goja.AssertFunction(jsonObject.Get("stringify"))
	config, err := parse(jsonObject, vm.ToValue(string(input)))
	if err != nil {
		return fmt.Errorf("invalid input config: %w", err)
	}

	if _, err := vm.RunScript(path, string(source)); err != nil {
		return err
	}
	apply, ok := goja.AssertFunction(vm.Get("main"))
	if !ok {
		return errors.New("expected a main(config) function")
	}
	result, err := apply(goja.Undefined(), config)
	if err != nil {
		return err
	}

	invalidResult := errors.New("main(config) must return a configuration object synchronously")
	object, ok := result.(*goja.Object)
	if !ok || object.ClassName() != "Object" || object.ExportType() == reflect.TypeFor[*goja.Promise]() {
		return invalidResult
	}
	encoded, err := stringify(jsonObject, result)
	if err != nil {
		return fmt.Errorf("cannot serialize the result: %w", err)
	}
	output := encoded.String()
	if !strings.HasPrefix(output, "{") {
		return invalidResult
	}
	_, err = fmt.Fprintln(os.Stdout, output)
	return err
}
