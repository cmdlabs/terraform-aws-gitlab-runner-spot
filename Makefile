.PHONY: docs check
docs:
	ruby erb/docs.rb

check:
	shellcheck --exclude=SC2154 template/user-data.sh.tpl

unit:
	bash shunit2/test_user_data.sh
