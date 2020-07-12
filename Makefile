default: clean textbook schema all ext-single-ttl check

all:
	./catttl.rb textbook textbook-rc curriculum curriculum-versions catalogue subject subjectArea subjectType school publisher schema shape dataset > all-`date +%Y%m%d`.ttl
	rapper -i turtle all-`date +%Y%m%d`.ttl -c
	ls -l all-`date +%Y%m%d`.ttl

clean:
	-rm -rf catalogue/ curriculum/ publisher/ *学校/
	-rm -rf en/catalogue/ en/curriculum/ en/publisher/ en/*学校/

textbook:
	ruby ./textbook.rb

ext-single-ttl:
	./ext-single-ttl.rb

check:
	./check.rb
	./check-link.rb en/index.html index.html about.html en/about.html 高等学校/2016/国総/359.html en/高等学校/2016/国総/359.html curriculum/中学校/2012/国語/国語.html en/curriculum/中学校/2012/国語/国語.html

schema:
	./schema.rb
