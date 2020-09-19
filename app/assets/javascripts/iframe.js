(function() {
  var isIFrame = window.parent !== window;
  if (!isIFrame) return;

  document.body.classList.add("body__iframe");

  var lastPageheight = null;
  function calculatePageHeight() {
    var content = document.querySelector(".navody-template__content");
    var height = content.clientHeight;

    if (lastPageheight !== height) {
      lastPageheight = height;
      window.parent.postMessage({ height, __NAVODY: true }, "*");
    }
  }

  const observer = new MutationObserver(calculatePageHeight);
  observer.observe(document.querySelector("body"), {
    attributes: true,
    childList: true,
    subtree: true
  });
  calculatePageHeight();
})();
