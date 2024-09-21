# Compiler Front-End For a Subset of Pascal

This is a syntax-directed translation scheme for a subset of the Pascal programming language. It generates ILOC code (assembly code for a simple abstract machine) that can run in an ILOC simulator using Flex and Bison. It uses a register-to-register model that maximizes opportunities for register allocation. 

## Usage
The executable can be generated using `make` in the `src` directory. 

To use, run `codegen` with a file containing Pascal code as input. The output will be the generated code. The ILOC simulator to run the code in is not provided. 
