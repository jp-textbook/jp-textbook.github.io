default: clean catalogue textbook all ext-single-ttl check

all:
	./catttl.rb textbook textbook-rc curriculum curriculum-versions catalogue subject subjectArea subjectType school publisher > all-`date +%Y%m%d`.ttl
	rapper -i turtle all-`date +%Y%m%d`.ttl -c

clean:
	-rm -rf catalogue/ curriculum/ publisher/ *学校/

textbook:
	ruby ./textbook.rb

ext-single-ttl:
	./ext-single-ttl.rb

catalogue:
	ruby ./catalogue.rb

check:
	./check.rb
