function get_nhk4school(cscode, page = 1) {
  /// NHK for School APIにアクセス
  const apiKey = 'QhnGtsNqZpAeaG4Sn4RlVhGs34XBL4Vq';
  const api = `https://api.nhk.or.jp/school/v1/nfsvideos/cscode/${cscode}?apikey=${apiKey}&page=${page}`;
  fetch(api)
  .then(response => {
      return response.json();
  })
  .then(data => {
      render_nhk4school(data, cscode);
  })
  .catch(function (error) {
      console.log(`失敗しました: ${error}`);
      render_nhk4school_results("<p>取得に失敗しました。</p>", page, false);
  });

  function render_nhk4school_results(html, cscode, page, success = true) {
      //結果を表示
      let elmResult = document.getElementById(`nhk4school-list-${cscode}-${page}`);
      elmResult.innerHTML = html;
      if (success) {
          let elmButton = document.getElementById(`nhk4school-button-${cscode}-${page}`);
          elmButton.disabled = true;
          if (page == 1) {
            let buttonText = `
            <button class="btn btn-outline-info btn-sm nhk4chool-toggle" type="button" data-toggle="collapse" data-target="#nhk4school-list-${cscode}-1" aria-controls="#nhk4school-list-${cscode}-1">
              一覧の開閉
            </button>
            `;
            elmButton.insertAdjacentHTML("afterend", buttonText);
            console.log(document.getElementById(`nhk4school-list-${cscode}-1`));
          }
      }
  }

  function render_nhk4school(data, cscode) {
      console.log(data);
      console.log(data['counts']);
      let html = ''; //出力するHTMLテキストを入れる変数
      if (data['error'] || !data['counts']) {
          html += "該当するコンテンツはありません";
      } else {
          //取得結果の概要を表示
          const pageStart = data['perPage'] * (data['page']-1) + 1;
          const pageEnd   = pageStart + data['result'].length - 1;
          html += `<p>NHK for Schoolの動画: ${data['counts']}件中 ${pageStart} - ${pageEnd} 件:</p>`;
          //コンテンツ一覧を表示
          html += `<div class="row">`;
          for (let i = 0; i < data['result'].length; i++){
              let seriesTitle = "";
              if (data['result'][i]['url'] && data['result'][i]['about'] && data['result'][i]['about']['nfsSeriesName']) {
                  seriesTitle = ` (${data['result'][i]['about']['nfsSeriesName']})`;
              }
              const result = `
                  <div class="col-md-4">
                    <div class="card shadow-sm">
                      <a href="${data['result'][i]['url']}"><img class="bd-placeholder-img card-img-top" width="100%" src="${data['result'][i]['thumbnailUrl']}"></img></a>
                      <div class="card-body small">
                        <p class="card-text">${data['result'][i]['name']}${seriesTitle}</p>
                        <p class="card-text">${data['result'][i]['description']}</p>
                        <button type="button" class="btn btn-outline-light"><a href="${data['result'][i]['url']}">動画を見る</a></button>
                      </div>
                    </div>
                  </div>
              `;
              //console.log(result);
              html += result;
          }
          html += '</div>';
      }
      if (data['page'] < data['totalPages']) {
          const nextPage = data['page'] + 1;
          html += `
              <button id="nhk4school-button-${cscode}-${nextPage}" type="button" class="btn btn-outline-info btn-sm btn-nhk4school p-1" onclick="get_nhk4school('${data['queryData']['curriculumStandardCode']}', ${nextPage})">
              次の${data['perPage']}件を取得 <i class="bi bi-search"></i>
              </button>
              <div id="nhk4school-list-${cscode}-${nextPage}" />
          `;
      }
      render_nhk4school_results(html, cscode, data['page']);
  };
};

let fetcher = new window.ldfetch();
function fetch_jp_cos(url, elem) {
  let main = async function () {
    let objects = await fetcher.get(url).then(response => {
      return fetcher.frame(response.triples, {'@graph':{}});
    });
    console.log(objects);
    objects["@graph"].forEach(e => {
      if (e["@id"] == url) {
        let parent = elem.parentNode;
        let cscode = e["http://purl.org/dc/terms/identifier"]["@value"];
        parent.innerHTML += ` <span class="sectionNumberHierarchy">${e["https://w3id.org/jp-cos/sectionNumberHierarchy"]["@value"]}</span>`;
        parent.innerHTML += `<br><span class="sectionText">${e["https://w3id.org/jp-cos/sectionText"]["@value"]}</span>`;
        //console.log(parent);
        parent.innerHTML += `
          <button id="nhk4school-button-${cscode}-1" class="btn btn-outline-info btn-sm btn-nhk4school p-1"
            onclick="get_nhk4school('${cscode}')">
            NHK for Schoolコンテンツを検索 <i class="bi bi-search"></i>
          </button>
          <div id="nhk4school-list-${cscode}-1" class="collapse show"></div>
        `;
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
