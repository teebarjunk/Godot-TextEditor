# Text Editor
Version 1.0

![](README/readme_preview.png)

***Warning: Use at your own risk. Backup your files before testing.***

# Features
- Tabs with scroll
- File filtering
- Highlighting for common file formats (`md` `json`...)
- Tag filtering system
- File Management:
	- Creation
	- Renaming
	- Recycling
- Auto save/load settings
- Many little *Ease of life* functions:
	- Folder open/close
	- Comment toggling for:
		- `.md`: `<!-- -->`
		- `.json`: `/* */`
		- `.ini`: `; `
		- `.cfg`: `; `
		- `.yaml`: `# `

# Controls
- `ctrl + W` Close file
- `ctrl + shift + W` Open last closed file 
- `ctrl + tab` Select next open file
- `ctrl + shift + tab` Select last open file
- `ctrl + mouse wheel` Adjust font size
- `ctrl + up` `ctrl + down` Move selected lines
- `ctrl + /` Toggle line comments
- `ctrl + M` Toggle file meta info

# Symbols and Tags
To make it easier to find stuff there is a *Symbol* viewer.

- `Markdown` uses headings `# Heading`
- `JSON` uses Dictionaries `"object": {`
- `YAML` uses Dictionaries `object: `
- `ini` `cfg` use headings `[heading]`

Symbols can have tags. Tags are added with comments.

- `Markdown` uses `<!-- #tag1 #tag2 -->`
- `JSON` uses `"#": "#tag1 #tag2"`
- `YAML` uses `# #tag1 #tag2` or `"#": "#tag1 #tag2"`
- `ini` `cfg` uses `; #tag1 #tag2`

Symbols are per file, tags are shared across files.

When a file is opened with tags, they show up in bottom right *Tag Container*.

Click them to toggle on and off.\
This will then highlight *Files* and *Symbols* that have that tag.

# Todo
- [ ] Preserve which folders are open/closed.
- [ ] Search
- [ ] Find and replace
- [ ] Meta data based on format.
- [ ] Recycle folder
- [ ] Undo recycle
