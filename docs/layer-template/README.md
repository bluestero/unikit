# example

A layer for [unikit](https://github.com/bluestero/unix-toolkit): one line on what it adds.
(This first paragraph is what `uk layers` shows on its about card.)

## Add it

```bash
uk layer add git@github.com:<owner>/<repo>.git example
```

unikit shows what of it runs on your machine and asks first; then it offers to set up its parts
(`tk install --layer=example`). `uk update` keeps it current.

## What's in it

| | |
|---|---|
| `example-hello` | says hello (a command, on PATH in every shell) |
| example-hello part | links `example-hello` into `~/.local/bin` (`tk install`) |
