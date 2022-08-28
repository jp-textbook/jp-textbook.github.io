let fetcher = new window.ldfetch();
function fetch_jp_cos(url, elem) {
  let main = async function () {
    let objects = await fetcher.get(url).then(response => {
      return fetcher.frame(response.triples, {'@graph':{}});
    });
    console.log(objects);
    objects["@graph"].forEach(e => {
      if (e["@id"] == url) {
        //console.log(e);
        //console.log(e["http://schema.org/description"]);
        elem.parentNode.innerHTML += `<br>${e["http://schema.org/description"]["@value"]}`;
      }
    });
  }
  try {
    main();
  } catch (e) {
    console.error(e);
  }
}
$("dl.row dd a").each(function(link){
  //let url = "https://w3id.org/jp-cos/8220233111000000";
  let url = this.href.toString();
  if (url.startsWith("https://w3id.org/jp-cos/")) {
    fetch_jp_cos(url, this);
  }
});
