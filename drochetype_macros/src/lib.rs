use proc_macro::TokenStream;
use quote::quote;
use syn::DeriveInput;

#[proc_macro_derive(IntoUsize)]
pub fn into_usize(input: TokenStream) -> TokenStream {
    let ast = syn::parse_macro_input!(input as DeriveInput);
    let name = &ast.ident;
    let expanded = quote! {
        impl From<#name> for usize {
            fn from(item: #name) -> Self {
                item as usize
            }
        }
        impl From<usize> for #name {
            fn from(item: usize) -> Self {
                #name::from_repr(item).unwrap()
            }
        }
        impl #name {
            fn increment(self) -> #name {
                ((self as usize + 1) % #name::COUNT).into()
            }
            fn decrement(self) -> #name {
                ((#name::COUNT + self as usize - 1) % #name::COUNT).into()
            }
        }
    };
    TokenStream::from(expanded)
}
