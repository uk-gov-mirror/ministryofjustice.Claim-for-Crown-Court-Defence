CaseType.find_or_create_by!(name: 'Appeal against conviction',    is_fixed_fee: true)
CaseType.find_or_create_by!(name: 'Appeal against sentence',      is_fixed_fee: true)
CaseType.find_or_create_by!(name: 'Appeal against conviction',    is_fixed_fee: false)
CaseType.find_or_create_by!(name: 'Breach of Crown Court order',  is_fixed_fee: true)
CaseType.find_or_create_by!(name: 'Commital for Sentence',        is_fixed_fee: true)
CaseType.find_or_create_by!(name: 'Contempt',                     is_fixed_fee: true)
CaseType.find_or_create_by!(name: 'Cracked Trial',                is_fixed_fee: false)
CaseType.find_or_create_by!(name: 'Cracked before retrial',       is_fixed_fee: false)
CaseType.find_or_create_by!(name: 'Discontinuance',               is_fixed_fee: false)
CaseType.find_or_create_by!(name: 'Elected cases not proceeded',  is_fixed_fee: true)
CaseType.find_or_create_by!(name: 'Guilty plea',                  is_fixed_fee: false)
CaseType.find_or_create_by!(name: 'Retrial',                      is_fixed_fee: false)
CaseType.find_or_create_by!(name: 'Trial',                        is_fixed_fee: false)
CaseType.find_or_create_by!(name: 'Fixed fee',                    is_fixed_fee: true)
