(ns memefactory.ui.components.form
  (:require-macros [reagent.ratom :refer [reaction]])
  (:require
   [reagent.core :as r]
   [district.ui.component.active-account :refer [active-account]]
   [district.ui.component.active-account-balance :refer [active-account-balance]]
   [re-frame.core :refer [subscribe dispatch]]
   [memefactory.ui.subs :as mf-subs]
   [memefactory.ui.utils :as mf-utils]
   [district.ui.component.form.input :as inputs :refer [text-input textarea-input]]
   [cljs.spec.alpha :as s]
   [spec-tools.core :as st]
   ))
(def registry (atom {}))
(s/def :example.place/city (s/and string?
                                  #(< 2 (count %))
                                  #(odd? (count %))))
(s/def :example.place/state string?)

(s/def :example.place/address (with-meta
                                (s/keys :req [:example.place/city :example.place/state])
                                {:message "Should be all"}))
(def err-defs {:preds {"(cljs.core/fn [%] (cljs.core/< 2 (cljs.core/count %)))" "Must be a long string"
                       "(cljs.core/fn [%] (cljs.core/contains? % :example.place/city))" "Must have a city"
                       "(cljs.core/fn [%] (cljs.core/odd? (cljs.core/count %)))" "Must be odd length"}
               :specs {[:example.place/address :example.place/city] {"(cljs.core/fn [%] (cljs.core/odd? (cljs.core/count %)))" "City must have odd length"}}})

(defn resolve-error [p ed]
  [(:in p)
   (if-let [m (get-in ed [:specs (:via p) (str (:pred p))])]
     m
     (if-let [m (get-in ed [:preds (str (:pred p))])]
       m
       (str (:pred p))))])

(defn xform-errors [data errs]
  (when-let [problems (::s/problems data)]
    (reduce (fn [acc p]
              (let [e (resolve-error p errs)]
                (if-not (empty? (first e))
                  (apply assoc-in acc e)
                  (assoc acc :all (last e)))))
             {}
             problems)))

(defn form []
  (let [form-data (r/atom {})
        errors (reaction {:local (xform-errors (s/explain-data :example.place/address @form-data)
                                               err-defs)})]
    (fn []
      [:div
       [:h1 "test"]
       [text-input {:form-data form-data
                    :id :example.place/state
                    :errors errors}]
       [textarea-input {:form-data form-data
                        :id :example.place/city
                        :errors errors}]])))
