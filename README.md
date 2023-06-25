# c64_assembler_egs
Example c64 Kick Assembler code.

## sid_egs
SID players using various interrupt techniques.

## basic_extender
A simple Basic extender. Includes bash like disk access. e.g. ls

## sprites
Animated sprite0 using on-the-fly sprite memory updates. Sprite movement via Joystick input. Using multisource IRQ routine.

## VS Code integration

With Kick Assembler extension.

| Key | Action |
|-----|--------|
| `F6` | Build and Run in VICE (aka c64sc) |
| `Shift F6` | Build and Run in Debugger (aka c64debugger) |

### Kick Assembler VS Code Extention Settings

```
"kickassembler.debugger.runtime": "/usr/bin/c64debugger",
"kickassembler.emulator.runtime": "/usr/bin/x64sc",
```