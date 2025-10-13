#!/bin/sh

#  CullTokenData.sh
#  Doubling Season
#
#  Created by DBenson on 8/21/24.
#  
curl -s './TokenLookup' | jq -r '.reverse-related'
