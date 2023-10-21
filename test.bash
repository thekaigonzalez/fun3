# Copyright 2019-2023 Kai D. Gonzalez

clear

rm ./test-1 &> /dev/null

gdc test.d errors.d lexer.d parser.d eval.d -o test-1

./test-1

read -r -p "=> Press any key to continue"
