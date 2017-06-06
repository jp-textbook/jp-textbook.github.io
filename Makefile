default: clean textbook curriculum

clean:
	-rm -rf curriculum/ *学校/

textbook:
	ruby ./textbook.rb

curriculum:
	ruby ./curricurum.rb
