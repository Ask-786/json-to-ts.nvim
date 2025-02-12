# json-to-ts.nvim

json-to-ts.nvim is a Neovim plugin that automatically converts JSON-like objects into TypeScript type definitions. It leverages Treesitter to parse JSON objects within your TypeScript files and recursively generates type definitions—helping you quickly and accurately create types from existing JSON data.

## Features

- **Automatic Type Generation:** Scans the JSON object where your cursor is placed and converts it into a TypeScript type.
- **Recursive Parsing:** Handles nested objects and arrays, creating separate type definitions for nested structures.
- **Seamless Integration:** Works directly within your TypeScript files (requires filetype `typescript`).

## Requirements

- **Neovim:** Version 0.5 or later is recommended.
- **Treesitter:** Ensure you have Treesitter installed and configured for TypeScript.

## Installation

You can install json-to-ts.nvim using your favorite plugin manager.

### Using Lazy

```lua
return {
  'ask-786/json-to-ts.nvim',
  config = function()
    local json_to_ts = require('json-to-ts')
    vim.keymap.set('n', '<leader>jt', json_to_ts.convert, { desc = 'Convert JSON to TS' })
  end,
}
```

## Usage

1. **Open a TypeScript File:**
   Make sure the filetype is set to `typescript`.

2. **Place Your Cursor:**
   Position your cursor inside a JSON object in the file.

3. **Run the Conversion Command:**
   Execute the following command:
   ```vim
   :lua require('json-to-ts').convert()
   ```
   The plugin checks that you are in a TypeScript file and that the cursor is within an object. It then generates the corresponding TypeScript type definitions and appends them at the end of your file.

## Example

Given the following JSON object in a TypeScript file:

```typescript
export const data = {
  name: "John",
  age: 30,
  isActive: true,
  roles: ["admin", "editor"],
  address: {
    street: "123 Main St",
    city: "Anytown",
  },
};
```

Running `:lua require('json-to-ts').convert()` will generate type definitions similar to:

```typescript
export type Address = {
  street: string;
  city: string;
};

export type Root = {
  name: string;
  age: number;
  isActive: boolean;
  roles: string[];
  address: Address;
};
```

These definitions are appended to the end of your current file, giving you an immediate reference for type checking and further development.
