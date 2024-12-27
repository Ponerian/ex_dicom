# ExDicom

ExDicom is an Elixir library for parsing DICOM (Digital Imaging and Communications in Medicine) files. It is basically a rough Elixir port of the [Cornerstone DICOM Parser](https://github.com/cornerstonejs/dicomParser) JavaScript library.

## Features

- Parse DICOM files with support for various transfer syntaxes
- Handle both explicit and implicit VR (Value Representation)
- Support for deflated transfer syntax
- Extract DICOM elements and attributes
- Read common DICOM data types (strings, integers, etc.)

## Installation

Add `ex_dicom` to your list of dependencies in `mix.exs`:

```elixir
def deps do
[
  {:ex_dicom, "~> 0.1.0"}
]
end
```

## Usage

Basic usage to parse a DICOM file:

```elixir
# Parse a DICOM file
{:ok, dataset} = ExDicom.parse_file("path/to/dicom/file.dcm")

# Access DICOM elements
patient_name = ExDicom.DataSet.string(dataset, "x00100010")
modality = ExDicom.DataSet.string(dataset, "x00080060")
rows = ExDicom.DataSet.uint16(dataset, "x00280010")
columns = ExDicom.DataSet.uint16(dataset, "x00280011")
```

## Credits

This library is an Elixir port of the [Cornerstone DICOM Parser](https://github.com/cornerstonejs/dicomParser) JavaScript library. Many thanks to the core team & all the contributors over there.

## License

This project is licensed under the [MIT License](LICENSE). The original Cornerstone DICOM Parser is also MIT licensed.
