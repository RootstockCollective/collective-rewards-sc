# generates lcov.info
forge coverage --no-match-test '(fork)' --report lcov

EXCLUDE="*test* *mock* *node_modules* *script*"
lcov \
    --rc branch_coverage=1 \
    --rc derive_function_end_line=0 \
    --remove lcov.info $EXCLUDE \
    --output-file lcov.info

genhtml lcov.info \
    --rc branch_coverage=1 \
    --rc derive_function_end_line=0 \
    --output-directory coverage