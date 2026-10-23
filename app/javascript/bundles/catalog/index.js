import BlacklightRangeLimit from "blacklight-range-limit";

BlacklightRangeLimit.init({ onLoadHandler: window.Blacklight.onLoad });

const validatedForms = new WeakSet();

window.Blacklight.onLoad(() => {
  document.querySelectorAll("form.range_limit_form").forEach((form) => {
    if (validatedForms.has(form)) return;
    validatedForms.add(form);

    const begin = form.querySelector(".range_begin");
    const end = form.querySelector(".range_end");
    const message = document.querySelector('meta[name="catalog-range-order-error"]').content;
    const error = form.querySelector("[data-range-validation-error]") || document.createElement("div");
    error.id = `${end.id}-error`;
    error.dataset.rangeValidationError = "true";
    error.className = "invalid-feedback d-block";
    error.setAttribute("aria-live", "polite");
    form.querySelector(".range-limit-input-group").appendChild(error);
    const descriptions = new Set((end.getAttribute("aria-describedby") || "").split(/\s+/).filter(Boolean));
    descriptions.add(error.id);
    end.setAttribute("aria-describedby", [...descriptions].join(" "));

    const validate = () => {
      const reversed = begin.value !== "" && end.value !== "" &&
        Number.isFinite(begin.valueAsNumber) && Number.isFinite(end.valueAsNumber) &&
        begin.valueAsNumber > end.valueAsNumber;
      end.setCustomValidity(reversed ? message : "");
      end.classList.toggle("is-invalid", reversed);
      end.setAttribute("aria-invalid", String(reversed));
      error.textContent = reversed ? message : "";
    };

    form.addEventListener("input", validate);
    form.addEventListener("change", validate);
    form.addEventListener("submit", (event) => {
      validate();
      if (!form.reportValidity()) event.preventDefault();
    });
    validate();
  });
});
