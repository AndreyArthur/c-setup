#include "runner.h"
#include <stdio.h>
#include <stdlib.h>

void test(char* message, bool (*callback)()) {
    printf("    %s: ", message);
    if (callback()) {
        printf("PASS\n");
        return;
    }
    printf("FAIL\n");
}

Runner* runner_init(char* spec) {
    Runner* runner = malloc(sizeof(Runner));
    runner->test = test;
    printf("Testing %s:\n", spec);
    return runner;
};

void runner_free(Runner* runner) { free(runner); }
