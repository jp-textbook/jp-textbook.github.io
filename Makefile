default: clean all ttl2html check

all:
	bundle exec catttl textbook textbook-rc \
	  curriculum curriculum-versions catalogue subject subjectArea subjectType school publisher schema \
	  shape dataset > all-textbook-`date +%Y%m%d`.ttl
	rapper -i turtle all-textbook-`date +%Y%m%d`.ttl -c
	@ls -l all-textbook-`date +%Y%m%d`.ttl
	gzip -9 -f all-textbook-`date +%Y%m%d`.ttl
	@ls -l all-textbook-`date +%Y%m%d`.ttl.gz
	bundle exec catttl chapterType compilingProspectus teachingUnit-AA-body teachingUnit-AA-duration teachingUnit-AB teachingUnitType > all-teachingUnit-`date +%Y%m%d`.ttl
	rapper -i turtle all-teachingUnit-`date +%Y%m%d`.ttl -c
	@ls -l all-teachingUnit-`date +%Y%m%d`.ttl
	gzip -9 -f all-teachingUnit-`date +%Y%m%d`.ttl
	@ls -l all-teachingUnit-`date +%Y%m%d`.ttl.gz

ttl2html:
	bundle exec ttl2html all-textbook-`date +%Y%m%d`.ttl.gz all-teachingUnit-`date +%Y%m%d`.ttl.gz
	cd en && bundle exec ttl2html ../all-textbook-`date +%Y%m%d`.ttl.gz ../all-teachingUnit-`date +%Y%m%d`.ttl.gz

clean:
	-rm -rf catalogue/ curriculum/ school/ publisher/ *学校/
	-rm -rf en/catalogue/ en/curriculum/ en/school/ en/publisher/ en/*学校/
	-rm -rf A[ABC]/

check:
	./check-link.rb en/index.html index.html about.html en/about.html 高等学校/2016/国総/359.html en/高等学校/2016/国総/359.html curriculum/中学校/2012/国語/国語.html en/curriculum/中学校/2012/国語/国語.html
	-gzip -cd all-textbook-`date +%Y%m%d`.ttl.gz all-teachingUnit-`date +%Y%m%d`.ttl.gz | pyshacl -s `ls -1 shape-*.ttl|tail -1` -o pyshacl.log -
	./check.rb
	#cd ../shaclex; sbt "run --data ../jp-textbook.github.io/all-`date +%Y%m%d`.ttl --engine shaclex --showValidationReport"
