const falconItems = {
  en: [
    {
      image: "image/1sokol.jpeg",
      title: "Power in Every Wingbeat",
      text: "A falcon flies with speed and control, showing confidence in every movement. Its wing rhythm is efficient and stable, helping it conserve energy during long flights."
    },
    {
      image: "image/2Sokol.jpeg",
      title: "Sharp Vision, Clear Focus",
      text: "Falcons can see far distances and react quickly, which makes them strong hunters. Their visual focus helps them track tiny movement even when flying at high speed."
    },
    {
      image: "image/3Sokol.jpeg",
      title: "Calm Under Pressure",
      text: "Even in wind and chaos, falcons stay balanced and make smart decisions. This calm behavior allows them to hunt with precision instead of wasting energy."
    },
    {
      image: "image/4Sokol.jpeg",
      title: "Fearless in the Sky",
      text: "Falcons are brave birds that are not afraid to climb high and attack fast. They often use altitude as a tactical advantage before starting a controlled dive."
    },
    {
      image: "image/5Sokol.jpeg",
      title: "Natural Leaders",
      text: "Their posture and flight style look proud and sure, like true leaders of the air. Every movement reflects discipline, awareness, and confidence."
    },
    {
      image: "image/6Sokol.jpeg",
      title: "Symbol of Confidence",
      text: "Falcons remind us that strength is not only power, but also precision and self-trust. They represent courage combined with intelligence and control."
    }
  ],
  ru: [
    {
      image: "image/1sokol.jpeg",
      title: "Сила в каждом взмахе",
      text: "Сокол летит быстро и точно, показывая уверенность в каждом движении. Ритм его крыльев экономичен и стабилен, что помогает сохранять энергию в длительном полете."
    },
    {
      image: "image/2Sokol.jpeg",
      title: "Острое зрение и фокус",
      text: "Соколы видят на большом расстоянии и мгновенно реагируют, как сильные охотники. Их визуальный фокус позволяет замечать малейшие движения даже на высокой скорости."
    },
    {
      image: "image/3Sokol.jpeg",
      title: "Спокойствие под давлением",
      text: "Даже в ветре и хаосе соколы сохраняют баланс и принимают верные решения. Такое спокойствие позволяет охотиться точнее и не тратить силы зря."
    },
    {
      image: "image/4Sokol.jpeg",
      title: "Бесстрашные в небе",
      text: "Соколы смелые птицы, которые не боятся набирать высоту и действовать быстро. Часто они используют высоту как тактическое преимущество перед точным пикированием."
    },
    {
      image: "image/5Sokol.jpeg",
      title: "Природные лидеры",
      text: "Их осанка и стиль полета выглядят уверенно, как у настоящих лидеров воздуха. В каждом движении чувствуется дисциплина, наблюдательность и самоконтроль."
    },
    {
      image: "image/6Sokol.jpeg",
      title: "Символ уверенности",
      text: "Соколы напоминают нам, что сила это не только мощь, но и точность и самодоверие. Они символизируют смелость, соединенную с интеллектом и контролем."
    }
  ]
};

const cardsEl = document.getElementById("cards");
const pageButtonsEl = document.getElementById("pageButtons");
const prevBtn = document.getElementById("prevBtn");
const nextBtn = document.getElementById("nextBtn");
const statusEl = document.getElementById("status");
const lightboxEl = document.getElementById("lightbox");
const lightboxImgEl = document.getElementById("lightboxImage");
const lightboxCloseEl = document.getElementById("lightboxClose");

const itemsPerPage = 2;
let currentPage = 1;
const cardTags = {
  en: ["Aerial Power", "Precision", "Discipline", "Fearless Mode", "Sky Leader", "Iconic Spirit"],
  ru: ["Сила неба", "Точность", "Дисциплина", "Режим бесстрашия", "Лидер высоты", "Символ духа"]
};

function renderCards() {
  const lang = localStorage.getItem("siteLang") || "en";
  const items = falconItems[lang] || falconItems.en;
  const totalPages = Math.ceil(items.length / itemsPerPage);
  if (currentPage > totalPages) currentPage = totalPages;

  const start = (currentPage - 1) * itemsPerPage;
  const pageItems = items.slice(start, start + itemsPerPage);
  const tags = cardTags[lang] || cardTags.en;

  cardsEl.innerHTML = pageItems
    .map(
      (item, index) => `
        <article class="card card-openable" tabindex="0" role="button" aria-label="${item.title}">
          <img src="${item.image}" alt="${item.title}" loading="lazy" data-full="${item.image}" />
          <div class="content">
            <div class="card-tag">${tags[start + index] || tags[index] || ""}</div>
            <h3>${item.title}</h3>
            <p>${item.text}</p>
          </div>
        </article>
      `
    )
    .join("");

  if (window.I18N && window.I18N[lang] && typeof window.I18N[lang].pageOf === "function") {
    statusEl.textContent = window.I18N[lang].pageOf(currentPage, totalPages);
  } else {
    statusEl.textContent = `Page ${currentPage} of ${totalPages}`;
  }
}

function renderButtons() {
  const lang = localStorage.getItem("siteLang") || "en";
  const items = falconItems[lang] || falconItems.en;
  const totalPages = Math.ceil(items.length / itemsPerPage);

  pageButtonsEl.innerHTML = "";

  for (let i = 1; i <= totalPages; i += 1) {
    const btn = document.createElement("button");
    btn.textContent = String(i);
    btn.className = `page-btn${i === currentPage ? " active" : ""}`;
    btn.setAttribute("aria-label", `Go to page ${i}`);
    btn.addEventListener("click", () => {
      currentPage = i;
      update();
    });
    pageButtonsEl.appendChild(btn);
  }

  prevBtn.disabled = currentPage === 1;
  nextBtn.disabled = currentPage === totalPages;
}

function update() {
  renderCards();
  renderButtons();
}

function openLightbox(imageSrc, altText) {
  if (!lightboxEl || !lightboxImgEl) return;
  lightboxImgEl.src = imageSrc;
  lightboxImgEl.alt = altText;
  lightboxEl.classList.add("open");
  lightboxEl.setAttribute("aria-hidden", "false");
}

function closeLightbox() {
  if (!lightboxEl || !lightboxImgEl) return;
  lightboxEl.classList.remove("open");
  lightboxEl.setAttribute("aria-hidden", "true");
  lightboxImgEl.src = "";
}

prevBtn.addEventListener("click", () => {
  if (currentPage > 1) {
    currentPage -= 1;
    update();
  }
});

nextBtn.addEventListener("click", () => {
  const lang = localStorage.getItem("siteLang") || "en";
  const items = falconItems[lang] || falconItems.en;
  const totalPages = Math.ceil(items.length / itemsPerPage);
  if (currentPage < totalPages) {
    currentPage += 1;
    update();
  }
});

window.addEventListener("site-language-change", () => {
  update();
});

cardsEl.addEventListener("click", (event) => {
  const card = event.target.closest(".card-openable");
  if (!card) return;
  const image = card.querySelector("img[data-full]");
  if (!image) return;
  openLightbox(image.dataset.full, image.alt);
});

cardsEl.addEventListener("keydown", (event) => {
  if (event.key !== "Enter" && event.key !== " ") return;
  const card = event.target.closest(".card-openable");
  if (!card) return;
  const image = card.querySelector("img[data-full]");
  if (!image) return;
  event.preventDefault();
  openLightbox(image.dataset.full, image.alt);
});

if (lightboxCloseEl) {
  lightboxCloseEl.addEventListener("click", closeLightbox);
}

if (lightboxEl) {
  lightboxEl.addEventListener("click", (event) => {
    if (event.target === lightboxEl) closeLightbox();
  });
}

document.addEventListener("keydown", (event) => {
  if (event.key === "Escape") closeLightbox();
});

update();
