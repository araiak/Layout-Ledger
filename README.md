# Layout Ledger

Layout Ledger is a World of Warcraft addon that allows you to easily import and export your UI and character settings. This is particularly useful for setting up a new character, or for sharing your settings with friends.

## Features

*   Export and import of:
    *   Action Bars
    *   Keybindings
    *   UI Layout
    *   Character Macros
    *   Global Macros
*   Easy-to-use interface.
*   Configuration panel in the standard WoW options menu.
*   Slash commands for quick access.

## Installation

1.  Download the latest version of the addon from the [releases page](https://github.com/Araiak/Layout-Ledger/releases).
2.  Extract the downloaded `.zip` file.
3.  Copy the `LayoutLedger` folder into your `World of Warcraft\_retail_\Interface\AddOns` directory.
4.  Restart World of Warcraft.

## Usage

### Main Window

You can open the main window by using the following slash commands:

*   `/layoutledger`
*   `/ll`

The main window provides a simple interface for exporting and importing your settings.

### Exporting

To export your settings, simply click the "Export" button. This will generate a string that you can copy and save. The settings that are exported can be configured in the options panel.

### Importing

To import settings, paste a previously exported string into the import box and click the "Import" button. You will be prompted to either "Override" or "Merge" the settings.

*   **Override:** This will replace your current settings with the imported settings.
*   **Merge:** This will merge the imported settings with your current settings. This is only available for settings that can be merged (e.g., macros and action bars).

## Configuration

You can configure the addon by going to the standard WoW options menu (press `Esc` -> `Options` -> `AddOns` -> `Layout Ledger`). Here you can select which settings you want to export.

## Contributing

Contributions are welcome! If you would like to contribute to the project, please feel free to fork the repository and submit a pull request.

## License

This project is licensed under the [MIT License](LICENSE).
