default: clean curriculum textbook all

all:
	./catttl.rb textbook curriculum catalogue subject subjectArea > all-`date +%Y%m%d`.ttl

clean:
	-rm -rf curriculum/ *学校/

textbook:
	ruby ./textbook.rb

curriculum:
	ruby ./curriculum.rb
