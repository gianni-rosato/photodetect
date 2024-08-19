# photodetect

`photodetect` is a command-line tool written in Zig that analyzes images to determine whether they are likely to be photographs or not. It uses the geometric mean of the image's Shannon entropy coefficient & the number of colors after palletization to 16 colors per channel to make this determination.

## Features

- Image entropy calculation
- Unique color counting
- Image palletization
- Geometric mean calculation of entropy & palletized unique colors
- Photographic likelihood determination with confidence interval

## Prerequisites

To build and run this program, you need:

- Zig compiler (0.13.0 or later)
- stb_image library (header-only library for image loading, present in the source code)

## Building

To build the program, run:

```
zig build
```

And check the `zig-out/bin` directory for the compiled binary.

## Usage

```bash
Usage: photodetect <image_file> <print_mode>
print mode:
	0: pretty
	1: verbose
	2: boolean
```

### Arguments

1. `<image_file>`: Path to the image file you want to analyze.
2. `<print_mode>`: Output format (0, 1, or 2)
   - 0: Pretty print (default)
   - 1: Verbose output
   - 2: Boolean output (True/False)

Depending on the print mode, the program will output:

- Pretty print: A summary of the analysis with a likelihood statement.
- Verbose: Detailed information including entropy, color counts, and confidence.
- Boolean: Simply "True" for likely photograph or "False" for unlikely photograph.

### Examples

1. Pretty print mode:
   ```bash
   ./photodetect path/to/image.png 0
   ```

2. Verbose mode:
   ```bash
   ./photodetect path/to/image.png 1
   ```

3. Boolean mode:
   ```bash
   ./photodetect path/to/image.png 2
   ```

## License

This project is licensed under the Apache 2.0 License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- This program uses the [stb_image](https://github.com/nothings/stb/blob/master/stb_image.h) library for image loading. `stb_image` is a public domain library by Sean Barrett. It is also available under the MIT License, Copyright (c) 2017 Sean Barrett.
