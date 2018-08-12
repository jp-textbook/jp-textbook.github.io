default: clean catalogue textbook all ext-single-ttl

all:
	./catttl.rb textbook textbook-rc curriculum curriculum-versions catalogue subject subjectArea subjectType school > all-`date +%Y%m%d`.ttl
	rapper -i turtle all-`date +%Y%m%d`.ttl -c

clean:
	-rm -rf catalogue/ curriculum/ *学校/

textbook:
	ruby ./textbook.rb

ext-single-ttl:
	./ext-single-ttl.rb

catalogue:
	ruby ./catalogue.rb
