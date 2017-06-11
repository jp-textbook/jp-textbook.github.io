default: clean curriculum catalogue textbook all

all:
	./catttl.rb textbook curriculum catalogue subject subjectArea > all-`date +%Y%m%d`.ttl

clean:
	-rm -rf catalogue/ curriculum/ *学校/

textbook:
	ruby ./textbook.rb

curriculum:
	ruby ./curriculum.rb

catalogue:
	ruby ./catalogue.rb
