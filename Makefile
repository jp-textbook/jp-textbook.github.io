default: clean all ttl2html check

all:
	./catttl.rb textbook textbook-rc \
	  curriculum curriculum-versions catalogue subject subjectArea subjectType school publisher schema \
	  chapterType compilingProspectus teachingUnit-AA-body teachingUnit-AA-duration teachingUnit-AB teachingUnitType \
	  shape dataset > all-`date +%Y%m%d`.ttl
	rapper -i turtle all-`date +%Y%m%d`.ttl -c
	ls -l all-`date +%Y%m%d`.ttl

ttl2html:
	bundle exec ttl2html all-`date +%Y%m%d`.ttl
	cd en && bundle exec ttl2html ../all-`date +%Y%m%d`.ttl

clean:
	-rm -rf catalogue/ curriculum/ school/ publisher/ *学校/
	-rm -rf en/catalogue/ en/curriculum/ en/school/ en/publisher/ en/*学校/
	-rm -rf A[ABC]/

check:
	./check.rb
	./check-link.rb en/index.html index.html about.html en/about.html 高等学校/2016/国総/359.html en/高等学校/2016/国総/359.html curriculum/中学校/2012/国語/国語.html en/curriculum/中学校/2012/国語/国語.html
	pyshacl -s `ls -1 shape-*.ttl|tail -1` all-`date +%Y%m%d`.ttl -o pyshacl.log
	#cd ../shaclex; sbt "run --data ../jp-textbook.github.io/all-`date +%Y%m%d`.ttl --engine shaclex --showValidationReport"
