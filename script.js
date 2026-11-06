// <html lang="ja"> または <html lang="en"> に応じて切り替える。
// lang属性がない場合は日本語にする。
const language = (document.documentElement.lang || "ja")
  .toLowerCase()
  .split("-")[0];

const messages = {
  ja: {
    fetchFailed: "取得に失敗しました。",
    noResults: "該当するコンテンツはありません",
    toggleList: "一覧の開閉",
    watchVideo: "動画を見る",
    searchVideos: "NHK for Schoolコンテンツを検索",
    resultSummary: (count, start, end) =>
      `NHK for Schoolの動画: ${count}件中 ${start} - ${end} 件:`,
    nextPage: count => `次の${count}件を取得`,
  },
  en: {
    fetchFailed: "Failed to retrieve videos.",
    noResults: "No matching content was found.",
    toggleList: "Show/hide results",
    watchVideo: "Watch video",
    searchVideos: "Search NHK for School videos",
    resultSummary: (count, start, end) =>
      `NHK for School videos: ${start}–${end} of ${count}:`,
    nextPage: count => `Load next ${count} videos`,
  },
};

const t = messages[language] || messages.ja;

// APIやRDFの文字列をHTMLに埋め込む際のエスケープ
function escapeHtml(value) {
  return String(value ?? "").replace(/[&<>"']/g, character => ({
    "&": "&amp;",
    "<": "&lt;",
    ">": "&gt;",
    '"': "&quot;",
    "'": "&#39;",
  })[character]);
}

async function get_nhk4school(cscode, page = 1) {
  const apiKey = "Ul2TEbnk3A9AeaTxXHkHjXoR3kdTGmAj";
  const api = new URL(
    `https://api.nhk.or.jp/school/v2/nfsvideos/cscode/${encodeURIComponent(cscode)}`
  );
  api.searchParams.set("apikey", apiKey);
  api.searchParams.set("page", page);

  try {
    const response = await fetch(api);
    if (!response.ok) {
      throw new Error(`HTTP ${response.status}`);
    }

    const data = await response.json();
    render_nhk4school(data);
  } catch (error) {
    console.error(error);
    render_nhk4school_results(
      `<p>${t.fetchFailed}</p>`,
      false
    );
  }

  function render_nhk4school_results(html, success = true) {
    const elmResult = document.getElementById(
      `nhk4school-list-${cscode}-${page}`
    );
    if (!elmResult) return;

    elmResult.innerHTML = html;

    if (success) {
      const elmButton = document.getElementById(
        `nhk4school-button-${cscode}-${page}`
      );
      if (!elmButton) return;

      elmButton.disabled = true;

      if (page === 1) {
        elmButton.insertAdjacentHTML("afterend", `
          <button
            class="btn btn-outline-info btn-sm nhk4chool-toggle"
            type="button"
            data-toggle="collapse"
            data-target="#nhk4school-list-${cscode}-1"
            aria-controls="nhk4school-list-${cscode}-1"
            aria-expanded="true"
          >
            ${t.toggleList}
          </button>
        `);
      }
    }
  }

  function render_nhk4school(data) {
    let html = "";

    if (data.error || !data.counts) {
      html = `<p>${t.noResults}</p>`;
    } else {
      const pageStart = data.perPage * (data.page - 1) + 1;
      const pageEnd = pageStart + data.result.length - 1;

      html += `<p>${
        t.resultSummary(data.counts, pageStart, pageEnd)
      }</p>`;

      html += '<div class="row">';

      for (const item of data.result) {
        const seriesName = item.about?.nfsSeriesName;
        const seriesTitle = seriesName ? ` (${seriesName})` : "";

        html += `
          <div class="col-md-4">
            <div class="card shadow-sm">
              <a href="${escapeHtml(item.url)}">
                <img
                  class="bd-placeholder-img card-img-top"
                  width="100%"
                  src="${escapeHtml(item.thumbnailUrl)}"
                  alt="${escapeHtml(item.name)}"
                >
              </a>
              <div class="card-body small">
                <p class="card-text">${
                  escapeHtml(item.name)
                }${escapeHtml(seriesTitle)}</p>
                <p class="card-text">${
                  escapeHtml(item.description)
                }</p>
                <a
                  class="btn btn-light"
                  href="${escapeHtml(item.url)}"
                >
                  ${t.watchVideo}
                </a>
              </div>
            </div>
          </div>
        `;
      }

      html += "</div>";
    }

    if (Number(data.page) < Number(data.totalPages)) {
      const nextPage = Number(data.page) + 1;

      html += `
        <button
          id="nhk4school-button-${cscode}-${nextPage}"
          type="button"
          class="btn btn-outline-info btn-sm btn-nhk4school p-1"
        >
          ${t.nextPage(data.perPage)}
          <i class="bi bi-search"></i>
        </button>
        <div id="nhk4school-list-${cscode}-${nextPage}"></div>
      `;

      render_nhk4school_results(html);

      document.getElementById(
        `nhk4school-button-${cscode}-${nextPage}`
      )?.addEventListener("click", () => {
        get_nhk4school(cscode, nextPage);
      });
    } else {
      render_nhk4school_results(html);
    }
  }
}

const fetcher = new window.ldfetch();

async function fetch_jp_cos(url, elem) {
  try {
    const response = await fetcher.get(url);
    const objects = await fetcher.frame(
      response.triples,
      { "@graph": {} }
    );

    for (const e of objects["@graph"]) {
      if (e["@id"] !== url) continue;

      const parent = elem.parentNode;
      const cscode = e["http://purl.org/dc/terms/identifier"]["@value"];
      const cos = e["https://w3id.org/jp-cos/courseOfStudy"]["@id"];
      const hierarchy =
        e["https://w3id.org/jp-cos/sectionNumberHierarchy"]["@value"];
      const sectionText =
        e["https://w3id.org/jp-cos/sectionText"]["@value"];

      parent.insertAdjacentHTML("beforeend", `
        <span class="sectionNumberHierarchy">${
          escapeHtml(hierarchy)
        }</span>
        <br>
        <span class="sectionText">${
          escapeHtml(sectionText)
        }</span>
      `);

      // RDFから取得した本文などは、すべての対象リンクに表示
      // NHKの検索ボタンは cs:cosItem のリンクだけに追加
      if (!elem.parentElement.matches(
        'dd[itemprop~="https://w3id.org/jp-cos/cosItem"]'
      )) {
        continue;
      }

      switch (cos) {
        case "https://w3id.org/jp-cos/Elementary/2017":
        case "https://w3id.org/jp-cos/LowerSecondary/2017":
        case "https://w3id.org/jp-cos/UpperSecondary/2018": {
          const button = document.createElement("button");
          button.id = `nhk4school-button-${cscode}-1`;
          button.type = "button";
          button.className =
            "btn btn-outline-info btn-sm btn-nhk4school p-1";
          button.innerHTML = `
            ${t.searchVideos} <i class="bi bi-search"></i>
          `;
          button.addEventListener("click", () => {
            get_nhk4school(cscode);
          });

          const list = document.createElement("div");
          list.id = `nhk4school-list-${cscode}-1`;
          list.className = "collapse show";

          parent.append(button, list);
          break;
        }
      }
    }
  } catch (error) {
    console.error(error);
  }
}

$("dl.row dd a").each(function () {
  const url = this.href.toString();

  if (url.startsWith("https://w3id.org/jp-cos/")) {
    fetch_jp_cos(url, this);
  }
});