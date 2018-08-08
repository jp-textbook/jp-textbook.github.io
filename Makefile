default: clean catalogue textbook all

all:
	./catttl.rb textbook textbook-rc curriculum curriculum-versions catalogue subject subjectArea school > all-`date +%Y%m%d`.ttl

clean:
	-rm -rf catalogue/ curriculum/ *学校/

textbook:
	ruby ./textbook.rb

curriculum:
	ruby ./curriculum.rb

catalogue:
	ruby ./catalogue.rb
