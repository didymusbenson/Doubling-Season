# Version 1.1.1 

## STATUS

TEST FLIGHT: PENDING
TEST TRACK: LIVE

## KNOWN ISSUES

### 1. Token Copies do not copy type. Splits do.

Just what the title says. When copying a token card, the newly created token does not contain type information. Found on Android, self-tested. Confirmed on iOS as well.

### 2. iPhone splash screen bleedover

The splash screen on iphones (at least iphone 16 and 16 pro max) has bleedover into a second line on "zombies&". The overall size of the font needs to either be slightly reduced or automatic sizing needs to better handle whatever margins/padding we're dealing with. Found on iphone simulator, self-tested.