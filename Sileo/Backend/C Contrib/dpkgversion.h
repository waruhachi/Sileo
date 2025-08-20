//
//  dpkgversion.h
//  Sileo
//
//  Created by Amy While on 21/07/2022.
//  Copyright © 2022 Sileo Team. All rights reserved.
//

#ifndef dpkgversion_h
#define dpkgversion_h

#include <ctype.h>
#include <errno.h>
#include <limits.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/types.h>

struct DpkgVersion {
    char *version;
    char *revision;
    uint epoch;
    uint8_t requiresFree;
};

int compareVersion(const char *version1, int version1Count,
                   const char *version2, int version2Count);

#endif /* dpkgversion_h */
