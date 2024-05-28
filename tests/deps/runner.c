#include "runner.h"
#include <stdio.h>

void test(char* message, bool (*callback)()) {
    printf("    %s: ", message);
    if (callback()) {
        printf("PASS\n");
        return;
    }
    printf("FAIL\n");
}

Runner runner_init(char* spec) {
    Runner runner;
    runner.test = test;
    printf("Testing %s:\n", spec);
    return runner;
};
