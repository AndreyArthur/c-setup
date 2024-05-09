#ifndef RUNNER_H
#define RUNNER_H

#include <stdbool.h>

typedef struct Runner {
    void (*test)(char* message, bool (*callback)());
} Runner;

Runner* runner_init(char* spec);

void runner_free(Runner* runner);

#endif
